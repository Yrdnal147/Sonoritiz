import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../core/utils/responsive_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/palette_service.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_animations.dart';
import '../../../../core/widgets/sonoritiz_icon_button.dart';
import '../../../../core/utils/share_utils.dart';

import '../../../home/data/repositories/catalog_repository.dart';
import '../cubit/player_cubit.dart';
import '../cubit/player_state.dart';
import '../widgets/queue_bottom_sheet.dart';
import '../../data/models/track_model.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'lyrics_screen.dart';
import 'karaoke_party_screen.dart';
import '../../../../core/services/screen_wake_service.dart';
import '../../../../features/library/presentation/cubit/library_cubit.dart';
import '../../../../features/library/presentation/cubit/library_state.dart';
import '../../../offline/presentation/cubit/download_cubit.dart';

import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../../core/widgets/track_context_menu.dart';
import '../widgets/player_components/player_track_info.dart';
import '../widgets/player_components/player_progress_bar.dart';
import '../widgets/player_components/player_primary_controls.dart';
import '../widgets/player_components/player_secondary_controls.dart';
import '../widgets/player_components/player_favorite_button.dart';
import '../widgets/player_components/player_audio_device_chip.dart';
import '../widgets/player_components/special_player_widgets.dart';
import '../widgets/player_components/immersive_player_widgets.dart';
import '../widgets/player_components/vertical_prism_player_widgets.dart';
import '../widgets/track_details_context_modal.dart';
import '../cubit/superlike_cubit.dart';
import '../cubit/superlike_state.dart';
import '../widgets/superlike_burst_overlay.dart';
import '../widgets/superlike_dialogs.dart';
import '../../../../core/widgets/superlike_torch_badge.dart';

class FullscreenPlayerScreen extends StatefulWidget {
  const FullscreenPlayerScreen({Key? key}) : super(key: key);

  @override
  State<FullscreenPlayerScreen> createState() => _FullscreenPlayerScreenState();
}

class _FullscreenPlayerScreenState extends State<FullscreenPlayerScreen> {
  static final Map<String, ImmersivePalette> _paletteCache = <String, ImmersivePalette>{};

  double _dragOffsetY = 0.0;
  Color? _dominantColor;
  ImmersivePalette _immersivePalette = ImmersivePalette.fallback;
  String? _lastCoverUrl;
  bool _isVideoMode = false;
  bool _isVideoLoading = false;
  bool _videoFitCover = true;
  bool _isPressingCover = false;
  bool _lastVideoPlaying = false;
  Duration _lastVideoDuration = Duration.zero;
  VideoPlayerController? _videoController;
  final YoutubeExplode _yt = YoutubeExplode();
  PageController? _pageController;
  final ScrollController _scrollController = ScrollController();
  bool _isProgrammaticPageChange = false;
  final GlobalKey<SuperlikeBurstOverlayState> _burstKey = GlobalKey<SuperlikeBurstOverlayState>();
  List<TrackModel> _similarTracks = [];
  bool _isLoadingSimilar = false;
  String? _lastSimilarArtist;

  @override
  void initState() {
    super.initState();
    ScreenWakeService.setKeepScreenOn(true);
    final state = context.read<PlayerCubit>().state;
    _pageController = PageController(initialPage: state.currentIndex >= 0 ? state.currentIndex : 0);
    final track = state.currentTrack;
    if (track != null) {
      if (track.coverUrl.isNotEmpty) {
        _updateDominantColor(track.coverUrl);
      }
      _loadSimilarTracks(track);
    }
  }

  void _loadSimilarTracks(TrackModel track) async {
    final cleanArtist = track.artistName.split(RegExp(r',|&|feat\.|ft\.', caseSensitive: false)).first.trim();
    final targetArtist = cleanArtist.isNotEmpty ? cleanArtist : track.artistName;
    if (_lastSimilarArtist == targetArtist && _similarTracks.isNotEmpty) return;
    _lastSimilarArtist = targetArtist;
    if (mounted) setState(() => _isLoadingSimilar = true);
    try {
      final repo = CatalogRepository();
      final tracks = await repo.getSimilarTracks(targetArtist, limit: 20);
      if (mounted) {
        setState(() {
          _similarTracks = tracks;
          _isLoadingSimilar = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSimilar = false);
    }
  }

  @override
  void dispose() {
    ScreenWakeService.setKeepScreenOn(false);
    _pageController?.dispose();
    _scrollController.dispose();
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
      setState(() {
        _isVideoLoading = true;
      });
      try {
        await cubit.pause();
        String youtubeId = track.id;

        if (track.id.startsWith('local_') || track.id.startsWith('deezer_') || !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(track.id)) {
          final genreLower = track.genre.toLowerCase();
          final bool isBook = track.id.startsWith('deezer_book_') || genreLower.contains('livre');
          final bool isPodcast = track.id.startsWith('deezer_podcast_') || genreLower.contains('podcast');
          final query = isBook
              ? "${track.title} ${track.artistName} livre audio complet"
              : (isPodcast
                  ? "${track.title} ${track.artistName} podcast épisode"
                  : "${track.artistName} ${track.title} official video");
          final searchResults = await _yt.search.search(query);
          if (searchResults.isNotEmpty) {
            youtubeId = searchResults.first.id.value;
          } else {
            throw Exception("Aucune vidéo trouvée pour ce titre");
          }
        }

        final manifest = await _yt.videos.streamsClient.getManifest(
          youtubeId,
          ytClients: [YoutubeApiClient.androidSdkless],
          requireWatchPage: false,
        );
        final muxed = manifest.muxed;

        if (muxed.isNotEmpty) {
          final streamInfo = muxed.withHighestBitrate();
          _videoController = VideoPlayerController.networkUrl(streamInfo.url);
          _lastVideoPlaying = false;
          _lastVideoDuration = Duration.zero;
          _videoController!.addListener(() {
            final val = _videoController?.value;
            if (val == null || !mounted) return;
            if (val.isPlaying != _lastVideoPlaying ||
                val.duration != _lastVideoDuration) {
              _lastVideoPlaying = val.isPlaying;
              _lastVideoDuration = val.duration;
              setState(() {});
            }
          });

          await _videoController!.initialize();
          await _videoController!.seekTo(currentPosition);

          if (mounted && _isVideoMode) {
            _lastVideoPlaying = true;
            _lastVideoDuration = _videoController!.value.duration;
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
          setState(() {
            _isVideoMode = false;
          });
          cubit.play();
        }
      } finally {
        if (mounted) {
          setState(() {
            _isVideoLoading = false;
          });
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
    final trimmed = coverUrl.trim();
    if (trimmed.isEmpty || _lastCoverUrl == trimmed) return;
    _lastCoverUrl = trimmed;

    final sharedCached = PaletteService.getCached(trimmed) ?? _paletteCache.remove(trimmed);
    if (sharedCached != null) {
      _paletteCache[trimmed] = sharedCached;
      if (mounted) {
        setState(() {
          _immersivePalette = sharedCached;
          _dominantColor = sharedCached.dominantColor;
        });
      }
      return;
    }

    try {
      final extracted = await PaletteService.getPalette(trimmed);
      if (_paletteCache.length >= 40) {
        _paletteCache.remove(_paletteCache.keys.first);
      }
      _paletteCache[trimmed] = extracted;

      if (mounted && _lastCoverUrl == trimmed) {
        setState(() {
          _immersivePalette = extracted;
          _dominantColor = extracted.dominantColor;
        });
      }
    } catch (_) {}
  }

  Widget _buildLivePositionBuilder({
    required Widget Function(BuildContext context, Duration position) builder,
  }) {
    if (_isVideoMode && _videoController != null) {
      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _videoController!,
        builder: (ctx, val, _) => builder(ctx, val.position),
      );
    }
    return BlocSelector<PlayerCubit, PlayerState, Duration>(
      selector: (s) => s.position,
      builder: builder,
    );
  }

  String _resolveSyncedLyricLine(PlayerState state, Duration position) {
    if (!state.isFreeLyricsMode ||
        state.currentLyrics == null ||
        !state.currentLyrics!.hasSynced) {
      return '';
    }
    final lines = state.currentLyrics!.parsedSyncedLyrics!;
    final positionMs = position.inMilliseconds;
    String currentLine = '';
    for (int i = 0; i < lines.length; i++) {
      if (positionMs >= lines[i].time.inMilliseconds) {
        currentLine = lines[i].text;
      } else {
        break;
      }
    }
    return currentLine;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildStyleQuickChip({
    required BuildContext sheetContext,
    required String id,
    required String currentStyle,
    required String label,
    required IconData icon,
  }) {
    final bool isSelected = currentStyle == id;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          Navigator.pop(sheetContext);
          await StorageService().setPlayerStyle(id);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.10),
              width: isSelected ? 1.2 : 0.9,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: isSelected ? AppColors.primary : Colors.white70,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreOptionsBottomSheet(BuildContext context, TrackModel track) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: AppDimensions.spacingMd),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 8),
                                child: Text(
                                  "Style du lecteur",
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              ValueListenableBuilder<String>(
                                valueListenable: StorageService.playerStyleNotifier,
                                builder: (ctx, activeStyle, _) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          _buildStyleQuickChip(
                                            sheetContext: sheetContext,
                                            id: 'vertical',
                                            currentStyle: activeStyle,
                                            label: 'Signature (Défaut)',
                                            icon: Icons.equalizer_rounded,
                                          ),
                                          const SizedBox(width: 8),
                                          _buildStyleQuickChip(
                                            sheetContext: sheetContext,
                                            id: 'default',
                                            currentStyle: activeStyle,
                                            label: 'Classique',
                                            icon: Icons.album_rounded,
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        ListTile(
                          leading: Icon(_isVideoMode ? Icons.audiotrack_outlined : Icons.videocam_outlined),
                          title: Text(_isVideoMode ? "Passer en mode audio" : "Passer en mode vidéo"),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _toggleVideoMode(context.read<PlayerCubit>().state.position);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.download_rounded),
                          title: const Text("Télécharger pour écoute hors-ligne"),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            if (!track.id.startsWith('local_')) {
                              context.read<DownloadCubit>().downloadTrack(track);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Téléchargement de « ${track.title} » lancé"),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.playlist_add),
                          title: const Text("Ajouter à la playlist"),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _showAddToPlaylistSheet(context, track);
                          },
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.playlist_play_rounded,
                            color: AppColors.primary,
                          ),
                          title: const Text(
                            "Lire ensuite",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            context.read<PlayerCubit>().playTrackNext(track);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("« ${track.title} » sera lu juste après"),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.queue_music_rounded),
                          title: const Text("Ajouter à la file d'attente"),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            context.read<PlayerCubit>().addToQueue(track);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("« ${track.title} » ajouté à la file d'attente"),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.timer_outlined),
                          title: const Text("Minuteur de sommeil"),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _showSleepTimerBottomSheet(context);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.share_rounded),
                          title: const Text("Partager"),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            ShareUtils.shareTrack(track);
                          },
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

  void _showSleepTimerBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return BlocProvider.value(
          value: context.read<PlayerCubit>(),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(AppDimensions.spacingLg),
                    child: Text("Minuteur de sommeil", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: BlocBuilder<PlayerCubit, PlayerState>(
                        builder: (context, state) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
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
                                    Navigator.pop(sheetContext);
                                  },
                                ),
                                const Divider(),
                              ],
                              _buildTimerOption(sheetContext, 15),
                              _buildTimerOption(sheetContext, 30),
                              _buildTimerOption(sheetContext, 45),
                              _buildTimerOption(sheetContext, 60),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimerOption(BuildContext sheetContext, int minutes) {
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: Text("$minutes minutes"),
      onTap: () {
        context.read<PlayerCubit>().startSleepTimer(Duration(minutes: minutes));
        Navigator.pop(sheetContext);
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

  void _seekTo(Duration newPosition) {
    if (_isVideoMode && _videoController != null) {
      _videoController!.seekTo(newPosition);
    } else {
      context.read<PlayerCubit>().seek(newPosition);
    }
  }

  void _togglePlayPause() {
    if (_isVideoMode && _videoController != null) {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    } else {
      context.read<PlayerCubit>().togglePlayPause();
    }
  }

  void _openQueueSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<PlayerCubit>(),
        child: const QueueBottomSheet(),
      ),
    );
  }

  void _openLyricsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<PlayerCubit>(),
          child: const LyricsScreen(),
        ),
      ),
    );
  }

  void _openKaraokePartyScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<PlayerCubit>(),
          child: const KaraokePartyScreen(),
        ),
      ),
    );
  }

  Future<void> _handleSuperlikeDoubleTap(TrackModel qTrack) async {
    final superlikeCubit = context.read<SuperlikeCubit>();
    final isSuper = superlikeCubit.isSuperliked(qTrack.id);
    if (isSuper) {
      await superlikeCubit.removeSuperlike(qTrack.id);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF1E140F),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
            content: Text("Retiré de vos Sonoritiz Superlikes."),
          ),
        );
      }
    } else {
      if (superlikeCubit.state.tracks.length < SuperlikeCubit.maxSuperlikes) {
        final added = await superlikeCubit.addSuperlike(qTrack);
        if (added) {
          _burstKey.currentState?.trigger();
        }
      } else {
        SuperlikeDialogs.showLimitDialog(
          context: context,
          newTrack: qTrack,
          onReplaced: () {
            _burstKey.currentState?.trigger();
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final dismissThreshold = screenHeight * 0.2;
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<String>(
      valueListenable: StorageService.playerStyleNotifier,
      builder: (context, playerStyle, _) {
        final bool isVertical = playerStyle != 'default';
        final bool usesPaletteAtmosphere = isVertical;
        final Color sheetBaseColor = usesPaletteAtmosphere ? _immersivePalette.deepColor : colorScheme.surface;

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is OverscrollNotification && notification.overscroll < 0) {
              setState(() {
                _dragOffsetY = (_dragOffsetY - notification.overscroll).clamp(0.0, screenHeight);
              });
            } else if (notification is ScrollUpdateNotification) {
              if (notification.metrics.pixels <= 0 && (notification.scrollDelta ?? 0) < 0) {
                setState(() {
                  _dragOffsetY = (_dragOffsetY - (notification.scrollDelta ?? 0)).clamp(0.0, screenHeight);
                });
              }
            } else if (notification is ScrollEndNotification) {
              if (_dragOffsetY > dismissThreshold) {
                Navigator.of(context).pop();
              } else if (_dragOffsetY > 0) {
                setState(() {
                  _dragOffsetY = 0.0;
                });
              }
            }
            return false;
          },
          child: AnimatedContainer(
            duration: AppAnimations.fast,
            transform: Matrix4.translationValues(0, _dragOffsetY, 0),
            decoration: BoxDecoration(
              color: sheetBaseColor
                  .withOpacity((1 - (_dragOffsetY / screenHeight)).clamp(0.2, 1.0)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXxl)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXxl)),
              child: Scaffold(
                backgroundColor: usesPaletteAtmosphere ? _immersivePalette.deepColor : Colors.transparent,
                body: BlocListener<PlayerCubit, PlayerState>(
                  listenWhen: (prev, cur) => prev.currentIndex != cur.currentIndex,
                  listener: (context, state) async {
                    if (_isVideoMode) {
                      final oldController = _videoController;
                      _videoController = null;
                      setState(() {
                        _isVideoMode = false;
                      });
                      oldController?.dispose();
                    }
                    final url = state.currentTrack?.coverUrl;
                    if (url != null && url.isNotEmpty) {
                      _updateDominantColor(url);
                    }
                    if (_pageController != null && _pageController!.hasClients) {
                      final currentPage = _pageController!.page?.round() ?? state.currentIndex;
                      if (currentPage != state.currentIndex) {
                        _isProgrammaticPageChange = true;
                        try {
                          if ((currentPage - state.currentIndex).abs() > 1) {
                            _pageController!.jumpToPage(state.currentIndex);
                          } else {
                            await _pageController!.animateToPage(
                              state.currentIndex,
                              duration: AppAnimations.normal,
                              curve: AppAnimations.standard,
                            );
                          }
                        } finally {
                          _isProgrammaticPageChange = false;
                        }
                      }
                    }
                    if (state.currentTrack != null) {
                      _loadSimilarTracks(state.currentTrack!);
                    }
                  },
                  child: Stack(
                    children: [
                      // Couche de fond selon le style actif (strictement isolée par RepaintBoundary, miniature 120px en VRAM)
                      if (usesPaletteAtmosphere)
                        Positioned.fill(
                          child: BlocSelector<PlayerCubit, PlayerState, String>(
                            selector: (state) => state.currentTrack?.coverUrl ?? '',
                            builder: (context, coverUrl) {
                              return ImmersiveAtmosphereBackground(
                                coverUrl: coverUrl,
                                palette: _immersivePalette,
                              );
                            },
                          ),
                        )
                      else ...[
                        Positioned.fill(
                          child: BlocSelector<PlayerCubit, PlayerState, String>(
                            selector: (state) => state.currentTrack?.coverUrl ?? '',
                            builder: (context, coverUrl) {
                              return AnimatedSwitcher(
                                duration: AppAnimations.slow,
                                child: SizedBox.expand(
                                  key: ValueKey(coverUrl),
                                  child: ClipRect(
                                    child: RepaintBoundary(
                                      child: Transform.scale(
                                        scale: 1.18,
                                        child: ImageFiltered(
                                          imageFilter: ImageFilter.blur(
                                            sigmaX: 16,
                                            sigmaY: 16,
                                            tileMode: TileMode.mirror,
                                          ),
                                          child: SonoritizArtwork(
                                            imageUrl: coverUrl,
                                            width: double.infinity,
                                            height: double.infinity,
                                            borderRadius: 0,
                                            fit: BoxFit.cover,
                                            cacheMaxDimension: 120,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned.fill(
                          child: AnimatedContainer(
                            duration: AppAnimations.slow,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(0.0, -0.25),
                                radius: 1.15,
                                colors: [
                                  _immersivePalette.dominantColor.withValues(alpha: 0.34),
                                  _immersivePalette.midColor.withValues(alpha: 0.28),
                                  Colors.black.withValues(alpha: 0.45),
                                ],
                                stops: const [0.0, 0.55, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ],

                      SafeArea(
                        top: false,
                        child: BlocBuilder<PlayerCubit, PlayerState>(
                          // Ignore les ticks de position (1x/sec) pour éviter tout rebuild global CPU/GPU
                          buildWhen: (prev, cur) =>
                              prev.currentTrack != cur.currentTrack ||
                              prev.currentIndex != cur.currentIndex ||
                              prev.queue != cur.queue ||
                              prev.isPlaying != cur.isPlaying ||
                              prev.isBuffering != cur.isBuffering ||
                              prev.duration != cur.duration ||
                              prev.isShuffleModeEnabled != cur.isShuffleModeEnabled ||
                              prev.loopMode != cur.loopMode ||
                              prev.isFreeLyricsMode != cur.isFreeLyricsMode ||
                              prev.currentLyrics != cur.currentLyrics ||
                              prev.playbackSource != cur.playbackSource,
                          builder: (context, state) {
                            if (!state.hasTrack) {
                              return const Center(
                                child: Text("Aucun morceau", style: TextStyle(color: Colors.white)),
                              );
                            }

                            final view = View.of(context);
                            final viewMediaQuery = MediaQueryData.fromView(view);
                            final dispatcherView = WidgetsBinding.instance.platformDispatcher.views.isNotEmpty
                                ? WidgetsBinding.instance.platformDispatcher.views.first
                                : view;
                            final double hardwareTopInset = dispatcherView.devicePixelRatio > 0
                                ? dispatcherView.padding.top / dispatcherView.devicePixelRatio
                                : 0.0;
                            final double statusBarHeight = [
                              MediaQuery.of(context).padding.top,
                              MediaQuery.of(context).viewPadding.top,
                              viewMediaQuery.padding.top,
                              viewMediaQuery.viewPadding.top,
                              hardwareTopInset,
                              38.0,
                            ].reduce(math.max);

                            final track = state.currentTrack!;
                            final isPlaying = _isVideoMode && _videoController != null
                                ? _videoController!.value.isPlaying
                                : state.isPlaying;
                            final duration = _isVideoMode &&
                                    _videoController != null &&
                                    _videoController!.value.duration.inMilliseconds > 0
                                ? _videoController!.value.duration
                                : state.duration;

                            final isDesktop =
                                ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isTablet(context);
                            final double coverSize = isDesktop
                                ? math.min(screenWidth / 2 - 32, screenHeight * 0.52)
                                : math.min(screenWidth - 24, screenHeight * 0.45);

                            final String sourceText = state.playbackSource.isNotEmpty
                                ? state.playbackSource
                                : (track.albumName.isNotEmpty &&
                                        track.albumName != 'YouTube Audio' &&
                                        track.albumName != 'Local Audio'
                                    ? "l'album ${track.albumName}"
                                    : "Sonoritiz Mix");

                            IconData sourceIcon = Icons.graphic_eq_rounded;
                            final lowerSource = sourceText.toLowerCase();
                            if (lowerSource.contains('playlist')) {
                              sourceIcon = Icons.queue_music_rounded;
                            } else if (lowerSource.contains('album')) {
                              sourceIcon = Icons.album_rounded;
                            } else if (lowerSource.contains('téléchargement')) {
                              sourceIcon = Icons.download_done_rounded;
                            } else if (lowerSource.contains('liké') || lowerSource.contains('favori')) {
                              sourceIcon = Icons.favorite_rounded;
                            } else if (lowerSource.contains('profil') || lowerSource.contains('artiste')) {
                              sourceIcon = Icons.person_rounded;
                            } else if (lowerSource.contains('locaux')) {
                              sourceIcon = Icons.folder_rounded;
                            }

                            final TrackModel? nextTrack =
                                context.read<PlayerCubit>().peekNextTrack;

                            final Rect? horizontalHinge =
                                ResponsiveUtils.horizontalHingeBounds(context);
                            final Rect? verticalHinge =
                                ResponsiveUtils.verticalHingeBounds(context);
                            final bool useSplitPlayer =
                                ResponsiveUtils.shouldUseSplitPlayer(context);

                            late final Widget activePlayerLayout;
                            if (horizontalHinge != null) {
                              activePlayerLayout = _buildTabletopFoldablePlayerLayout(
                                context: context,
                                state: state,
                                track: track,
                                isPlaying: isPlaying,
                                duration: duration,
                                screenWidth: screenWidth,
                                statusBarHeight: statusBarHeight,
                                sourceText: sourceText,
                                sourceIcon: sourceIcon,
                                hingeBounds: horizontalHinge,
                              );
                            } else if (useSplitPlayer) {
                              activePlayerLayout = _buildWidescreenSplitPlayerLayout(
                                context: context,
                                state: state,
                                track: track,
                                isPlaying: isPlaying,
                                duration: duration,
                                screenHeight: screenHeight,
                                screenWidth: screenWidth,
                                statusBarHeight: statusBarHeight,
                                sourceText: sourceText,
                                sourceIcon: sourceIcon,
                                verticalHinge: verticalHinge,
                              );
                            } else if (isVertical) {
                              activePlayerLayout = _buildVerticalPrismPlayerLayout(
                                context: context,
                                state: state,
                                track: track,
                                isPlaying: isPlaying,
                                duration: duration,
                                screenHeight: screenHeight,
                                screenWidth: screenWidth,
                                statusBarHeight: statusBarHeight,
                                dismissThreshold: dismissThreshold,
                                sourceText: sourceText,
                                sourceIcon: sourceIcon,
                              );
                            } else {
                              activePlayerLayout = _buildDefaultPlayerLayout(
                                context: context,
                                state: state,
                                track: track,
                                isPlaying: isPlaying,
                                duration: duration,
                                screenHeight: screenHeight,
                                statusBarHeight: statusBarHeight,
                                dismissThreshold: dismissThreshold,
                                coverSize: coverSize,
                                sourceText: sourceText,
                                sourceIcon: sourceIcon,
                                colorScheme: colorScheme,
                              );
                            }

                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                activePlayerLayout,
                                // Bannière « À suivre » (surgit de la gauche vers la droite à -30s pendant 7s sur les 4 lecteurs)
                                Positioned(
                                  top: statusBarHeight + 56,
                                  left: 14,
                                  child: _buildLivePositionBuilder(
                                    builder: (context, livePos) {
                                      return SonoritizUpNextTeaserBanner(
                                        currentTrackId: track.id,
                                        nextTrack: nextTrack,
                                        position: livePos,
                                        duration: duration,
                                        accentColor: usesPaletteAtmosphere
                                            ? _immersivePalette.accentColor
                                            : AppColors.primary,
                                        onTapNext: () =>
                                            context.read<PlayerCubit>().playNext(),
                                      );
                                    },
                                  ),
                                ),
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
      },
    );
  }

  Duration _currentEffectivePosition() {
    if (_isVideoMode && _videoController != null) {
      return _videoController!.value.position;
    }
    return context.read<PlayerCubit>().state.position;
  }

  void _showDownloadSnackBar(TrackModel track) {
    final dlState = context.read<DownloadCubit>().state;
    final isQueuedOrActive =
        dlState is DownloadStateData && dlState.activeTasks.containsKey(track.id);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isQueuedOrActive
              ? "Téléchargement de « ${track.title} » lancé"
              : "Retiré des téléchargements : « ${track.title} »",
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// ===========================================================================
  /// LECTEUR GRAND ÉCRAN & PLIABLE LIVRE (Z Fold déplié, Tablette, PC >= 660dp)
  /// En-tête pleine largeur | Scène 2 colonnes équilibrées + Rail d'outils détaché à droite | Sons similaires en dessous
  /// ===========================================================================
  Widget _buildWidescreenSplitPlayerLayout({
    required BuildContext context,
    required PlayerState state,
    required TrackModel track,
    required bool isPlaying,
    required Duration duration,
    required double screenHeight,
    required double screenWidth,
    required double statusBarHeight,
    required String sourceText,
    required IconData sourceIcon,
    required Rect? verticalHinge,
  }) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double effectiveWidth =
              constraints.maxWidth.isFinite && constraints.maxWidth > 0
                  ? constraints.maxWidth
                  : screenWidth;
          final double effectiveHeight =
              constraints.maxHeight.isFinite && constraints.maxHeight > 0
                  ? constraints.maxHeight
                  : (screenHeight - statusBarHeight);
          final double stageHeight = math.max(540.0, effectiveHeight);
          final double hingeGap = verticalHinge != null
              ? math.max(20.0, verticalHinge.width)
              : 36.0;
          final double maxStageWidth = math.min(effectiveWidth - 48.0, 1280.0);
          final double halfColWidth =
              ((maxStageWidth - hingeGap - 72.0) / 2.0).clamp(240.0, 520.0);
          final double artworkSide = math
              .min(halfColWidth, stageHeight - 136.0)
              .clamp(240.0, 440.0);

          return SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // 1. SCÈNE PRINCIPALE PLEINE HAUTEUR (En-tête + 2 Colonnes centrées + Rail à droite)
                SizedBox(
                  height: stageHeight,
                  width: effectiveWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    child: Column(
                      children: [
                        // EN-TÊTE SUPÉRIEUR PLEINE LARGEUR (⌄ à gauche | Source centrée | ••• à droite)
                        Row(
                          children: [
                            ImmersiveGlassCircleButton(
                              tooltip: 'Fermer',
                              onTap: () => Navigator.pop(context),
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Container(
                                  constraints:
                                      const BoxConstraints(maxWidth: 420),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.34),
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusPill,
                                    ),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.16),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        sourceIcon,
                                        size: 14,
                                        color: Colors.white
                                            .withValues(alpha: 0.92),
                                      ),
                                      const SizedBox(width: 7),
                                      Flexible(
                                        child: Text(
                                          sourceText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            ImmersiveGlassCircleButton(
                              tooltip: 'Options',
                              onTap: () =>
                                  _showMoreOptionsBottomSheet(context, track),
                              child: const Icon(
                                Icons.more_horiz_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // CORPS 2 COLONNES ÉQUILIBRÉES + RAIL D'ACTIONS DÉTACHÉ
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 1280),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // COLONNE GAUCHE : Pochette / Vidéo centrée (sans rail superposé)
                                  Expanded(
                                    flex: 5,
                                    child: Center(
                                      child: SizedBox(
                                        width: artworkSide,
                                        height: artworkSide,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(28),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: _immersivePalette
                                                        .dominantColor
                                                        .withValues(
                                                            alpha: 0.45),
                                                    blurRadius: 38,
                                                    spreadRadius: 2,
                                                    offset:
                                                        const Offset(0, 14),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(28),
                                                child: PageView.builder(
                                                  controller: _pageController,
                                                  physics:
                                                      const BouncingScrollPhysics(),
                                                  onPageChanged: (index) {
                                                    if (_isProgrammaticPageChange) {
                                                      return;
                                                    }
                                                    context
                                                        .read<PlayerCubit>()
                                                        .skipToQueueItem(index);
                                                  },
                                                  itemCount:
                                                      state.queue.length,
                                                  itemBuilder:
                                                      (context, index) {
                                                    final qTrack =
                                                        state.queue[index];
                                                    final isCurrent = index ==
                                                        state.currentIndex;
                                                    if (isCurrent &&
                                                        _isVideoMode &&
                                                        _videoController !=
                                                            null &&
                                                        _videoController!
                                                            .value
                                                            .isInitialized) {
                                                      return GestureDetector(
                                                        onDoubleTap: () {
                                                          setState(() =>
                                                              _videoFitCover =
                                                                  !_videoFitCover);
                                                        },
                                                        child: ColoredBox(
                                                          color: Colors.black,
                                                          child: FittedBox(
                                                            fit: _videoFitCover
                                                                ? BoxFit.cover
                                                                : BoxFit
                                                                    .contain,
                                                            child: SizedBox(
                                                              width: _videoController!
                                                                          .value
                                                                          .size
                                                                          .width >
                                                                      0
                                                                  ? _videoController!
                                                                      .value
                                                                      .size
                                                                      .width
                                                                  : 1280,
                                                              height: _videoController!
                                                                          .value
                                                                          .size
                                                                          .height >
                                                                      0
                                                                  ? _videoController!
                                                                      .value
                                                                      .size
                                                                      .height
                                                                  : 720,
                                                              child: VideoPlayer(
                                                                  _videoController!),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                    return GestureDetector(
                                                      onLongPressStart: (_) {
                                                        TrackDetailsContextModal
                                                            .show(
                                                          context,
                                                          qTrack,
                                                          playbackSource:
                                                              sourceText,
                                                        );
                                                      },
                                                      onDoubleTap: () {
                                                        if (isCurrent) {
                                                          _handleSuperlikeDoubleTap(
                                                              qTrack);
                                                        }
                                                      },
                                                      child: SonoritizArtwork(
                                                        imageUrl:
                                                            qTrack.coverUrl,
                                                        width: artworkSide,
                                                        height: artworkSide,
                                                        borderRadius: 0,
                                                        fit: BoxFit.cover,
                                                        cacheMaxDimension: 900,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 14,
                                              left: 14,
                                              child: BlocSelector<
                                                  SuperlikeCubit,
                                                  SuperlikeState,
                                                  bool>(
                                                selector: (slState) => slState
                                                    .isSuperliked(track.id),
                                                builder: (context, isSuper) {
                                                  if (!isSuper) {
                                                    return const SizedBox
                                                        .shrink();
                                                  }
                                                  return const SuperlikeTorchBadge(
                                                    size:
                                                        TorchBadgeSize.medium,
                                                    showBackground: true,
                                                  );
                                                },
                                              ),
                                            ),
                                            IgnorePointer(
                                              child: SizedBox(
                                                width: artworkSide * 0.85,
                                                height: artworkSide * 0.85,
                                                child: SuperlikeBurstOverlay(
                                                    key: _burstKey),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  SizedBox(width: hingeGap),

                                  // COLONNE DROITE : Scène Signature centrée verticalement face à la pochette
                                  Expanded(
                                    flex: 5,
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                            maxWidth: 480),
                                        child: SingleChildScrollView(
                                          physics:
                                              const BouncingScrollPhysics(),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              if (state.isFreeLyricsMode &&
                                                  state.currentLyrics != null &&
                                                  state.currentLyrics!
                                                      .hasSynced)
                                                _buildLivePositionBuilder(
                                                  builder:
                                                      (context, livePos) {
                                                    final line =
                                                        _resolveSyncedLyricLine(
                                                            state, livePos);
                                                    if (line.isEmpty) {
                                                      return const SizedBox
                                                          .shrink();
                                                    }
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets
                                                              .fromLTRB(
                                                              12, 0, 12, 14),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 16,
                                                          vertical: 8,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.black
                                                              .withValues(
                                                                  alpha: 0.60),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      16),
                                                          border: Border.all(
                                                            color: _immersivePalette
                                                                .accentColor
                                                                .withValues(
                                                                    alpha:
                                                                        0.38),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          line,
                                                          textAlign:
                                                              TextAlign.center,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                            color:
                                                                Colors.white,
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w800,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              BlocSelector<SuperlikeCubit,
                                                  SuperlikeState, bool>(
                                                selector: (slState) => slState
                                                    .isSuperliked(track.id),
                                                builder: (context, isSuper) {
                                                  return SonoritizCoverVibrationStage(
                                                    track: track,
                                                    isPlaying: isPlaying,
                                                    isSuperliked: isSuper,
                                                    palette: _immersivePalette,
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: 16),
                                              BlocSelector<SuperlikeCubit,
                                                  SuperlikeState, bool>(
                                                selector: (slState) => slState
                                                    .isSuperliked(track.id),
                                                builder: (context, isSuper) {
                                                  return _buildLivePositionBuilder(
                                                    builder:
                                                        (context, livePos) {
                                                      return SonoritizCenteredScrubber(
                                                        position: livePos,
                                                        duration: duration,
                                                        isSuperliked: isSuper,
                                                        palette:
                                                            _immersivePalette,
                                                        onSeek: _seekTo,
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: 14),
                                              SonoritizSignatureTransportRow(
                                                isPlaying: isPlaying,
                                                isBuffering: !_isVideoMode &&
                                                    state.isBuffering,
                                                isShuffleModeEnabled: state
                                                    .isShuffleModeEnabled,
                                                loopMode: state.loopMode,
                                                palette: _immersivePalette,
                                                onPlayPause: _togglePlayPause,
                                                onPrevious: () => context
                                                    .read<PlayerCubit>()
                                                    .playPrevious(),
                                                onNext: () => context
                                                    .read<PlayerCubit>()
                                                    .playNext(),
                                                onShuffle: () => context
                                                    .read<PlayerCubit>()
                                                    .toggleShuffle(),
                                                onRepeat: () => context
                                                    .read<PlayerCubit>()
                                                    .toggleRepeat(),
                                              ),
                                              const SizedBox(height: 18),
                                              SonoritizTrackArtistsFrames(
                                                track: track,
                                                palette: _immersivePalette,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 16),

                                  // RAIL D'ACTIONS VERTICAL DÉTACHÉ À DROITE (ne chevauche jamais la pochette)
                                  Center(
                                    child: SonoritizRightActionRail(
                                      currentTrack: track,
                                      palette: _immersivePalette,
                                      isVideoMode: _isVideoMode,
                                      isVideoLoading: _isVideoLoading,
                                      onToggleVideo: () => _toggleVideoMode(
                                          _currentEffectivePosition()),
                                      onLyricsTapped: _openLyricsScreen,
                                      onQueueTapped: _openQueueSheet,
                                      onDownloadFeedback: () =>
                                          _showDownloadSnackBar(track),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. SECTION 20 SONS SIMILAIRES EN BAS AU DÉFILEMENT
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: _buildSimilarTracksSection(
                    track,
                    isSpecial: false,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// ===========================================================================
  /// MODE TABLETOP / FLEX (Galaxy Z Fold plié à 90° horizontalement)
  /// Moitié haute (au-dessus du pli) : Vidéo / Pochette | Moitié basse : Contrôles
  /// ===========================================================================
  Widget _buildTabletopFoldablePlayerLayout({
    required BuildContext context,
    required PlayerState state,
    required TrackModel track,
    required bool isPlaying,
    required Duration duration,
    required double screenWidth,
    required double statusBarHeight,
    required String sourceText,
    required IconData sourceIcon,
    required Rect hingeBounds,
  }) {
    final double topPaneHeight =
        (hingeBounds.top - statusBarHeight).clamp(180.0, 420.0);
    final double hingeHeight = hingeBounds.height.clamp(8.0, 40.0);

    return SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: topPaneHeight,
            width: screenWidth,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImmersiveMeltingCoverMask(
                  child: SonoritizArtwork(
                    imageUrl: track.coverUrl,
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0,
                    fit: BoxFit.cover,
                    cacheMaxDimension: 800,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ImmersiveGlassCircleButton(
                        tooltip: 'Fermer',
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      ImmersiveGlassCircleButton(
                        tooltip: 'Options',
                        onTap: () => _showMoreOptionsBottomSheet(context, track),
                        child: const Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: hingeHeight),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  SonoritizCoverVibrationStage(
                    track: track,
                    isPlaying: isPlaying,
                    isSuperliked:
                        context.read<SuperlikeCubit>().isSuperliked(track.id),
                    palette: _immersivePalette,
                  ),
                  const SizedBox(height: 10),
                  _buildLivePositionBuilder(
                    builder: (context, livePos) {
                      return SonoritizCenteredScrubber(
                        position: livePos,
                        duration: duration,
                        isSuperliked: context
                            .read<SuperlikeCubit>()
                            .isSuperliked(track.id),
                        palette: _immersivePalette,
                        onSeek: _seekTo,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  SonoritizSignatureTransportRow(
                    isPlaying: isPlaying,
                    isBuffering: !_isVideoMode && state.isBuffering,
                    isShuffleModeEnabled: state.isShuffleModeEnabled,
                    loopMode: state.loopMode,
                    palette: _immersivePalette,
                    onPlayPause: _togglePlayPause,
                    onPrevious: () => context.read<PlayerCubit>().playPrevious(),
                    onNext: () => context.read<PlayerCubit>().playNext(),
                    onShuffle: () => context.read<PlayerCubit>().toggleShuffle(),
                    onRepeat: () => context.read<PlayerCubit>().toggleRepeat(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ===========================================================================
  /// 4E LECTEUR : SIGNATURE SONORITIZ (Croquis : Pochette fondue + Blocs vibrants couleur pochette + Barre 5 outils)
  /// ===========================================================================
  Widget _buildVerticalPrismPlayerLayout({
    required BuildContext context,
    required PlayerState state,
    required TrackModel track,
    required bool isPlaying,
    required Duration duration,
    required double screenHeight,
    required double screenWidth,
    required double statusBarHeight,
    required double dismissThreshold,
    required String sourceText,
    required IconData sourceIcon,
  }) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double viewportHeight = math.max(590.0, screenHeight - bottomInset);
    final double coverStageHeight = viewportHeight * 0.64;

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          SizedBox(
            height: viewportHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Pochette Plein Écran bord-à-bord (64 % du haut) fondue dans sa couleur
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: coverStageHeight,
                  child: ImmersiveMeltingCoverMask(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (index) {
                        if (_isProgrammaticPageChange) return;
                        context.read<PlayerCubit>().skipToQueueItem(index);
                      },
                      itemCount: state.queue.length,
                      itemBuilder: (context, index) {
                        final qTrack = state.queue[index];
                        final isCurrent = index == state.currentIndex;

                        if (isCurrent &&
                            _isVideoMode &&
                            _videoController != null &&
                            _videoController!.value.isInitialized) {
                          return GestureDetector(
                            onDoubleTap: () {
                              setState(() => _videoFitCover = !_videoFitCover);
                            },
                            child: ColoredBox(
                              color: Colors.black,
                              child: FittedBox(
                                fit: _videoFitCover ? BoxFit.cover : BoxFit.contain,
                                child: SizedBox(
                                  width: _videoController!.value.size.width > 0
                                      ? _videoController!.value.size.width
                                      : 1280,
                                  height: _videoController!.value.size.height > 0
                                      ? _videoController!.value.size.height
                                      : 720,
                                  child: VideoPlayer(_videoController!),
                                ),
                              ),
                            ),
                          );
                        }

                        return GestureDetector(
                          key: ValueKey('signature_sonoritiz_page_${qTrack.id}_$index'),
                          onLongPressStart: (_) {
                            TrackDetailsContextModal.show(
                              context,
                              qTrack,
                              playbackSource: sourceText,
                            );
                          },
                          onDoubleTap: () {
                            if (isCurrent) _handleSuperlikeDoubleTap(qTrack);
                          },
                          child: SonoritizArtwork(
                            imageUrl: qTrack.coverUrl,
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: 0,
                            alignment: const Alignment(0, -0.2),
                            fit: BoxFit.cover,
                            cacheMaxDimension: 1400,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 2. Micro-voile de lisibilité en haut uniquement pour la barre d'état
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: statusBarHeight + 56,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x47000000),
                            Color(0x00000000),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Badge Superlike discret à gauche + animation d'éclat au double-clic
                Positioned(
                  top: statusBarHeight + 54,
                  left: 18,
                  child: BlocSelector<SuperlikeCubit, SuperlikeState, bool>(
                    selector: (slState) => slState.isSuperliked(track.id),
                    builder: (context, isSuper) {
                      if (!isSuper) return const SizedBox.shrink();
                      return const SuperlikeTorchBadge(
                        size: TorchBadgeSize.medium,
                        showBackground: true,
                      );
                    },
                  ),
                ),
                Positioned(
                  top: statusBarHeight + 32,
                  left: 0,
                  right: 0,
                  height: coverStageHeight * 0.65,
                  child: IgnorePointer(
                    child: Center(
                      child: SizedBox(
                        width: screenWidth * 0.70,
                        height: screenWidth * 0.70,
                        child: SuperlikeBurstOverlay(key: _burstKey),
                      ),
                    ),
                  ),
                ),

                // 4. En-tête supérieur (⌄ à gauche | Texte de source parfaitement centré au milieu | ••• à droite)
                Positioned(
                  top: statusBarHeight + 6,
                  left: 16,
                  right: 16,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) {
                      if ((details.primaryDelta ?? 0) > 0) {
                        setState(() {
                          _dragOffsetY += details.primaryDelta!;
                        });
                      }
                    },
                    onVerticalDragEnd: (_) {
                      if (_dragOffsetY > dismissThreshold) {
                        Navigator.of(context).pop();
                      } else if (_dragOffsetY > 0) {
                        setState(() => _dragOffsetY = 0.0);
                      }
                    },
                    child: Row(
                      children: [
                        ImmersiveGlassCircleButton(
                          tooltip: 'Fermer',
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.32),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    sourceIcon,
                                    size: 13.5,
                                    color: Colors.white.withValues(alpha: 0.92),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      sourceText,
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.94),
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ImmersiveGlassCircleButton(
                          tooltip: 'Options',
                          onTap: () => _showMoreOptionsBottomSheet(context, track),
                          child: const Icon(
                            Icons.more_horiz_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 5. Pilule verticale à droite sous (•••) (style Halo Orbital) :
                //    Regroupe Vidéo • Favoris/Superlike • Paroles • File • Sortie • Télécharger • Partager
                Positioned(
                  top: statusBarHeight + 54,
                  right: 14,
                  child: SonoritizRightActionRail(
                    currentTrack: track,
                    palette: _immersivePalette,
                    isVideoMode: _isVideoMode,
                    isVideoLoading: _isVideoLoading,
                    onToggleVideo: () => _toggleVideoMode(_currentEffectivePosition()),
                    onLyricsTapped: _openLyricsScreen,
                    onQueueTapped: _openQueueSheet,
                    onDownloadFeedback: () => _showDownloadSnackBar(track),
                  ),
                ),

                // 6. Scène « Signature Sonoritiz » remontée et aérée :
                //    Paroles agrandies + Titre/Artiste + Animation + Scrubber centré + Transports + Photos des artistes plus grandes en bas
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.isFreeLyricsMode &&
                          state.currentLyrics != null &&
                          state.currentLyrics!.hasSynced)
                        _buildLivePositionBuilder(
                          builder: (context, livePos) {
                            final line = _resolveSyncedLyricLine(state, livePos);
                            if (line.isEmpty) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.60),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _immersivePalette.accentColor.withValues(alpha: 0.38),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.32),
                                      blurRadius: 12,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  line,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                    letterSpacing: 0.1,
                                    shadows: [
                                      Shadow(
                                        color: Color(0x99000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                      // Titre & Artiste centrés + Animation de vibration juste après le nom de l'artiste
                      BlocSelector<SuperlikeCubit, SuperlikeState, bool>(
                        selector: (slState) => slState.isSuperliked(track.id),
                        builder: (context, isSuper) {
                          return SonoritizCoverVibrationStage(
                            track: track,
                            isPlaying: isPlaying,
                            isSuperliked: isSuper,
                            palette: _immersivePalette,
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // 00:00 • 03:20 centré + Jauge horizontale calibrée avec curseur rond
                      BlocSelector<SuperlikeCubit, SuperlikeState, bool>(
                        selector: (slState) => slState.isSuperliked(track.id),
                        builder: (context, isSuper) {
                          return _buildLivePositionBuilder(
                            builder: (context, livePos) {
                              return SonoritizCenteredScrubber(
                                position: livePos,
                                duration: duration,
                                isSuperliked: isSuper,
                                palette: _immersivePalette,
                                onSeek: _seekTo,
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      // Contrôles de transport : Shuffle • Précédent • Play • Suivant • Repeat
                      SonoritizSignatureTransportRow(
                        isPlaying: isPlaying,
                        isBuffering: !_isVideoMode && state.isBuffering,
                        isShuffleModeEnabled: state.isShuffleModeEnabled,
                        loopMode: state.loopMode,
                        palette: _immersivePalette,
                        onPlayPause: _togglePlayPause,
                        onPrevious: () => context.read<PlayerCubit>().playPrevious(),
                        onNext: () => context.read<PlayerCubit>().playNext(),
                        onShuffle: () => context.read<PlayerCubit>().toggleShuffle(),
                        onRepeat: () => context.read<PlayerCubit>().toggleRepeat(),
                      ),

                      const SizedBox(height: 16),

                      // En bas sous les boutons Play/Pause : Photos des artistes concernés par le son (plus grandes)
                      SonoritizTrackArtistsFrames(
                        track: track,
                        palette: _immersivePalette,
                      ),

                      const SizedBox(height: 10),

                      // Indice bas : ⌄ Découvrez de nouveaux sons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white.withValues(alpha: 0.50),
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Découvrez des sons similaires",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Section 20 sons similaires fondue dans la même couleur profonde
          _buildSimilarTracksSection(
            track,
            isSpecial: false,
            backgroundColor: _immersivePalette.deepColor,
          ),
        ],
      ),
    );
  }

  /// ===========================================================================
  /// 3E LECTEUR : HALO ORBITAL (Pochette fondue + Cadran rotatif 360° + Rail flottant)
  /// ===========================================================================
  Widget _buildImmersivePlayerLayout({
    required BuildContext context,
    required PlayerState state,
    required TrackModel track,
    required bool isPlaying,
    required Duration duration,
    required double screenHeight,
    required double screenWidth,
    required double statusBarHeight,
    required double dismissThreshold,
    required String sourceText,
    required IconData sourceIcon,
  }) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double viewportHeight = math.max(580.0, screenHeight - bottomInset);
    final double coverStageHeight = viewportHeight * 0.68;
    final double leftRailTop = (coverStageHeight - 172.0)
        .clamp(statusBarHeight + 84.0, coverStageHeight - 110.0);

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          SizedBox(
            height: viewportHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Pochette Plein Écran bord-à-bord (0 marge) fondue dans la palette
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: coverStageHeight,
                  child: ImmersiveMeltingCoverMask(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (index) {
                        if (_isProgrammaticPageChange) return;
                        context.read<PlayerCubit>().skipToQueueItem(index);
                      },
                      itemCount: state.queue.length,
                      itemBuilder: (context, index) {
                        final qTrack = state.queue[index];
                        final isCurrent = index == state.currentIndex;

                        if (isCurrent &&
                            _isVideoMode &&
                            _videoController != null &&
                            _videoController!.value.isInitialized) {
                          return GestureDetector(
                            onDoubleTap: () {
                              setState(() => _videoFitCover = !_videoFitCover);
                            },
                            child: ColoredBox(
                              color: Colors.black,
                              child: FittedBox(
                                fit: _videoFitCover ? BoxFit.cover : BoxFit.contain,
                                child: SizedBox(
                                  width: _videoController!.value.size.width > 0
                                      ? _videoController!.value.size.width
                                      : 1280,
                                  height: _videoController!.value.size.height > 0
                                      ? _videoController!.value.size.height
                                      : 720,
                                  child: VideoPlayer(_videoController!),
                                ),
                              ),
                            ),
                          );
                        }

                        return GestureDetector(
                          key: ValueKey('immersive_page_${qTrack.id}_$index'),
                          onLongPressStart: (_) {
                            TrackDetailsContextModal.show(
                              context,
                              qTrack,
                              playbackSource: sourceText,
                            );
                          },
                          onDoubleTap: () {
                            if (isCurrent) _handleSuperlikeDoubleTap(qTrack);
                          },
                          child: SonoritizArtwork(
                            imageUrl: qTrack.coverUrl,
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: 0,
                            alignment: const Alignment(0, -0.2),
                            fit: BoxFit.cover,
                            cacheMaxDimension: 1400,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 2. Micro-voile de protection en haut uniquement pour l'heure et les boutons sur pochette blanche
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: statusBarHeight + 56,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x47000000),
                            Color(0x00000000),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Badge Superlike discret en haut à droite sous l'en-tête + éclat au double-clic
                Positioned(
                  top: statusBarHeight + 54,
                  right: 18,
                  child: BlocSelector<SuperlikeCubit, SuperlikeState, bool>(
                    selector: (slState) => slState.isSuperliked(track.id),
                    builder: (context, isSuper) {
                      if (!isSuper) return const SizedBox.shrink();
                      return const SuperlikeTorchBadge(
                        size: TorchBadgeSize.medium,
                        showBackground: true,
                      );
                    },
                  ),
                ),
                Positioned(
                  top: statusBarHeight + 36,
                  left: 0,
                  right: 0,
                  height: coverStageHeight * 0.65,
                  child: IgnorePointer(
                    child: Center(
                      child: SizedBox(
                        width: screenWidth * 0.72,
                        height: screenWidth * 0.72,
                        child: SuperlikeBurstOverlay(key: _burstKey),
                      ),
                    ),
                  ),
                ),

                // 4. Rail vertical flottant à gauche dans la brume de fusion (Favori • Paroles • File)
                Positioned(
                  left: 16,
                  top: leftRailTop,
                  child: ImmersiveFloatingSideRail(
                    track: track,
                    onLyricsTapped: _openLyricsScreen,
                    onKaraokeTapped: _openKaraokePartyScreen,
                    onQueueTapped: _openQueueSheet,
                  ),
                ),

                // 5. En-tête flottant minimaliste (glisser vers le bas pour fermer)
                Positioned(
                  top: statusBarHeight + 6,
                  left: 16,
                  right: 16,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) {
                      if ((details.primaryDelta ?? 0) > 0) {
                        setState(() {
                          _dragOffsetY += details.primaryDelta!;
                        });
                      }
                    },
                    onVerticalDragEnd: (_) {
                      if (_dragOffsetY > dismissThreshold) {
                        Navigator.of(context).pop();
                      } else if (_dragOffsetY > 0) {
                        setState(() => _dragOffsetY = 0.0);
                      }
                    },
                    child: Row(
                      children: [
                        ImmersiveGlassCircleButton(
                          tooltip: 'Fermer',
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    sourceIcon,
                                    size: 13,
                                    color: Colors.white.withValues(alpha: 0.90),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      sourceText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.92),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ImmersiveGlassCircleButton(
                          tooltip: _isVideoMode ? 'Mode audio' : 'Voir le clip',
                          isHighlighted: _isVideoMode,
                          onTap: () => _toggleVideoMode(_currentEffectivePosition()),
                          child: _isVideoLoading
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: RepaintBoundary(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Icon(
                                  _isVideoMode
                                      ? Icons.headphones_rounded
                                      : Icons.play_circle_outline_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                        const SizedBox(width: 8),
                        ImmersiveGlassCircleButton(
                          tooltip: 'Options',
                          onTap: () => _showMoreOptionsBottomSheet(context, track),
                          child: const Icon(
                            Icons.more_horiz_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 6. Scène « Halo Orbital » 100 % originale (Affiche Cinéma + Cadran 360° + Ailes sculptées)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 6,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.isFreeLyricsMode &&
                          state.currentLyrics != null &&
                          state.currentLyrics!.hasSynced)
                        _buildLivePositionBuilder(
                          builder: (context, livePos) {
                            final line = _resolveSyncedLyricLine(state, livePos);
                            if (line.isEmpty) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(68, 0, 22, 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.34),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.14),
                                  ),
                                ),
                                child: Text(
                                  line,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                      // Titre centré style affiche cinéma + compteur tabulaire
                      _buildLivePositionBuilder(
                        builder: (context, livePos) {
                          return ImmersiveCinemaTitleStage(
                            track: track,
                            position: livePos,
                            duration: duration,
                            palette: _immersivePalette,
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Cadran central Halo Orbital (Anneau 360° tactile + Ailes latérales)
                      BlocSelector<SuperlikeCubit, SuperlikeState, bool>(
                        selector: (slState) => slState.isSuperliked(track.id),
                        builder: (context, isSuper) {
                          return _buildLivePositionBuilder(
                            builder: (context, livePos) {
                              return ImmersiveOrbitalControlHub(
                                position: livePos,
                                duration: duration,
                                isPlaying: isPlaying,
                                isBuffering: !_isVideoMode && state.isBuffering,
                                isSuperliked: isSuper,
                                isShuffleModeEnabled: state.isShuffleModeEnabled,
                                loopMode: state.loopMode,
                                palette: _immersivePalette,
                                onPlayPause: _togglePlayPause,
                                onPrevious: () => context.read<PlayerCubit>().playPrevious(),
                                onNext: () => context.read<PlayerCubit>().playNext(),
                                onShuffle: () => context.read<PlayerCubit>().toggleShuffle(),
                                onRepeat: () => context.read<PlayerCubit>().toggleRepeat(),
                                onSeek: _seekTo,
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 14),

                      // Pastille compacte Sortie Audio & Hors-ligne
                      ImmersiveCompactDevicePill(
                        currentTrack: track,
                        onDownloadFeedback: () => _showDownloadSnackBar(track),
                      ),

                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white.withValues(alpha: 0.50),
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Découvrez des sons similaires",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Section 20 sons similaires fondue dans la même couleur profonde
          _buildSimilarTracksSection(
            track,
            isSpecial: false,
            backgroundColor: _immersivePalette.deepColor,
          ),
        ],
      ),
    );
  }

  /// ===========================================================================
  /// NOUVEAU LECTEUR SPÉCIAL ÉPURÉ (Pochette fondue dans le noir + Pilules Studio + Spectre plein + Vagues libres)
  /// ===========================================================================
  Widget _buildSpecialPlayerLayout({
    required BuildContext context,
    required PlayerState state,
    required TrackModel track,
    required bool isPlaying,
    required Duration duration,
    required double screenHeight,
    required double screenWidth,
    required double statusBarHeight,
    required double dismissThreshold,
    required String sourceText,
    required IconData sourceIcon,
  }) {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          SizedBox(
            height: screenHeight - statusBarHeight - 4,
            child: Column(
              children: [
                    SizedBox(height: statusBarHeight + 8),

                    // Header minimaliste
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Bouton Fermer circulaire en verre
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF221A15).withValues(alpha: 0.85),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    width: 1.0,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                            // Label discret "ÉCOUTÉ DEPUIS..."
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  "ÉCOUTÉ DEPUIS $sourceText".toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.60),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            // Bouton Options circulaire en verre
                            GestureDetector(
                              onTap: () => _showMoreOptionsBottomSheet(context, track),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF221A15).withValues(alpha: 0.85),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    width: 1.0,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.more_horiz_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Zone Pochette Cinéma avec fondu vers le noir (fade-to-black) + Titre & Artiste qui émergent du noir
                    Expanded(
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            physics: const BouncingScrollPhysics(),
                            onPageChanged: (index) {
                              if (_isProgrammaticPageChange) return;
                              context.read<PlayerCubit>().skipToQueueItem(index);
                            },
                            itemCount: state.queue.length,
                            itemBuilder: (context, index) {
                              final qTrack = state.queue[index];
                              final isCurrent = index == state.currentIndex;

                              if (isCurrent &&
                                  _isVideoMode &&
                                  _videoController != null &&
                                  _videoController!.value.isInitialized) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(32),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          blurRadius: 22,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(32),
                                      child: FittedBox(
                                        fit: _videoFitCover ? BoxFit.cover : BoxFit.contain,
                                        child: SizedBox(
                                          width: _videoController!.value.size.width > 0
                                              ? _videoController!.value.size.width
                                              : 1280,
                                          height: _videoController!.value.size.height > 0
                                              ? _videoController!.value.size.height
                                              : 720,
                                          child: VideoPlayer(_videoController!),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return GestureDetector(
                                onLongPressStart: (_) {
                                  TrackDetailsContextModal.show(
                                    context,
                                    qTrack,
                                    playbackSource: sourceText,
                                  );
                                },
                                onDoubleTap: () {
                                  if (isCurrent) _handleSuperlikeDoubleTap(qTrack);
                                },
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Grande image Cinéma aux coins très arrondis
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(32),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.65),
                                              blurRadius: 22,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(32),
                                          child: SonoritizArtwork(
                                            imageUrl: qTrack.coverUrl,
                                            width: double.infinity,
                                            height: double.infinity,
                                            borderRadius: 32,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Badge Superlike discret en haut à gauche
                                    Positioned(
                                      top: 16,
                                      left: 42,
                                      child: BlocBuilder<SuperlikeCubit, SuperlikeState>(
                                        builder: (context, slState) {
                                          if (!slState.isSuperliked(qTrack.id)) {
                                            return const SizedBox.shrink();
                                          }
                                          return const SuperlikeTorchBadge(
                                            size: TorchBadgeSize.medium,
                                            showBackground: true,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          // Animation flambeau Superlike
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Center(
                                child: SizedBox(
                                  width: screenWidth * 0.75,
                                  height: screenWidth * 0.75,
                                  child: SuperlikeBurstOverlay(key: _burstKey),
                                ),
                              ),
                            ),
                          ),

                          // Paroles synchronisées en pastille flottante en bas de l'image
                          if (state.isFreeLyricsMode &&
                              state.currentLyrics != null &&
                              state.currentLyrics!.hasSynced)
                            _buildLivePositionBuilder(
                              builder: (context, livePos) {
                                final currentLyricLine = _resolveSyncedLyricLine(state, livePos);
                                if (currentLyricLine.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Positioned(
                                  left: 20,
                                  right: 20,
                                  bottom: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.72),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(alpha: 0.35),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Text(
                                      currentLyricLine,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFFFD180),
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 3. Le Dock Solaire Flottant ("Solar Dock Island")
                    _buildLivePositionBuilder(
                      builder: (context, livePos) => SpecialSolarDockCard(
                        currentTrack: track,
                        isPlaying: isPlaying,
                        isBuffering: !_isVideoMode && state.isBuffering,
                        position: livePos,
                        duration: duration,
                        isShuffleModeEnabled: state.isShuffleModeEnabled,
                        loopMode: state.loopMode,
                        isVideoMode: _isVideoMode,
                        isVideoLoading: _isVideoLoading,
                        onPlayPause: _togglePlayPause,
                        onPrevious: () => context.read<PlayerCubit>().playPrevious(),
                        onNext: () => context.read<PlayerCubit>().playNext(),
                        onShuffle: () => context.read<PlayerCubit>().toggleShuffle(),
                        onRepeat: () => context.read<PlayerCubit>().toggleRepeat(),
                        onSeek: _seekTo,
                        onLyricsTapped: _openLyricsScreen,
                        onQueueTapped: _openQueueSheet,
                        onVideoTapped: () => _toggleVideoMode(_currentEffectivePosition()),
                      ),
                    ),
              ],
            ),
          ),

          // Section 20 sons similaires au scroll vers le bas
          _buildSimilarTracksSection(track, isSpecial: true),
        ],
      ),
    );
  }

  /// ===========================================================================
  /// LECTEUR PAR DÉFAUT (CLASSIQUE)
  /// ===========================================================================
  Widget _buildDefaultPlayerLayout({
    required BuildContext context,
    required PlayerState state,
    required TrackModel track,
    required bool isPlaying,
    required Duration duration,
    required double screenHeight,
    required double statusBarHeight,
    required double dismissThreshold,
    required double coverSize,
    required String sourceText,
    required IconData sourceIcon,
    required ColorScheme colorScheme,
  }) {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          SizedBox(
            height: screenHeight - statusBarHeight - 8,
            child: Column(
              children: [
                SizedBox(height: statusBarHeight + 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SonoritizIconButton(
                              icon: Icons.keyboard_arrow_down_rounded,
                              tooltip: "Fermer",
                              color: Colors.white,
                              onPressed: () => Navigator.pop(context),
                            ),
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        sourceIcon,
                                        size: 13,
                                        color: Colors.white.withOpacity(0.85),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          "Écouté depuis $sourceText",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.88),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SonoritizIconButton(
                              icon: Icons.more_vert_rounded,
                              tooltip: "Options",
                              color: Colors.white,
                              onPressed: () => _showMoreOptionsBottomSheet(context, track),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Center(
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const BouncingScrollPhysics(),
                          onPageChanged: (index) {
                            if (_isProgrammaticPageChange) return;
                            context.read<PlayerCubit>().skipToQueueItem(index);
                          },
                          itemCount: state.queue.length,
                          itemBuilder: (context, index) {
                            final qTrack = state.queue[index];
                            final isCurrent = index == state.currentIndex;

                            if (isCurrent &&
                                _isVideoMode &&
                                _videoController != null &&
                                _videoController!.value.isInitialized) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
                                child: Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_dominantColor ?? Colors.black).withOpacity(0.55),
                                        blurRadius: 32,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        FittedBox(
                                          fit: _videoFitCover ? BoxFit.cover : BoxFit.contain,
                                          child: SizedBox(
                                            width: _videoController!.value.size.width > 0
                                                ? _videoController!.value.size.width
                                                : 1280,
                                            height: _videoController!.value.size.height > 0
                                                ? _videoController!.value.size.height
                                                : 720,
                                            child: VideoPlayer(_videoController!),
                                          ),
                                        ),
                                        Positioned(
                                          right: 10,
                                          top: 10,
                                          child: GestureDetector(
                                            onTap: () => _toggleVideoMode(_currentEffectivePosition()),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xE6141414),
                                                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                                                border: Border.all(
                                                  color: Colors.white.withOpacity(0.22),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.headphones_rounded, color: Colors.white, size: 14),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    "Mode audio",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 10,
                                          bottom: 10,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _videoFitCover = !_videoFitCover;
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.55),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white24),
                                              ),
                                              child: Icon(
                                                _videoFitCover
                                                    ? Icons.fit_screen_rounded
                                                    : Icons.crop_free_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            final double targetScale = _isPressingCover && isCurrent
                                ? 0.94
                                : ((isCurrent && isPlaying) ? 1.0 : 0.93);

                            return Center(
                              key: ValueKey('page_item_${qTrack.id}_$index'),
                              child: GestureDetector(
                                onTapDown: (_) {
                                  if (isCurrent) setState(() => _isPressingCover = true);
                                },
                                onTapUp: (_) {
                                  if (_isPressingCover) setState(() => _isPressingCover = false);
                                },
                                onTapCancel: () {
                                  if (_isPressingCover) setState(() => _isPressingCover = false);
                                },
                                onLongPressStart: (_) {
                                  setState(() => _isPressingCover = false);
                                  TrackDetailsContextModal.show(
                                    context,
                                    qTrack,
                                    playbackSource: sourceText,
                                  );
                                },
                                onDoubleTap: () {
                                  if (isCurrent) _handleSuperlikeDoubleTap(qTrack);
                                },
                                child: AnimatedScale(
                                  scale: targetScale,
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutBack,
                                  child: Container(
                                    width: coverSize,
                                    height: coverSize,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _immersivePalette.dominantColor
                                              .withValues(alpha: isPlaying ? 0.45 : 0.28),
                                          blurRadius: isPlaying ? 32 : 20,
                                          spreadRadius: isPlaying ? 2 : 0,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          SonoritizArtwork(
                                            imageUrl: qTrack.coverUrl,
                                            width: coverSize,
                                            height: coverSize,
                                            borderRadius: 24,
                                            fit: BoxFit.cover,
                                          ),
                                          Positioned(
                                            top: 14,
                                            left: 14,
                                            child: BlocBuilder<SuperlikeCubit, SuperlikeState>(
                                              builder: (context, slState) {
                                                if (!slState.isSuperliked(qTrack.id)) return const SizedBox.shrink();
                                                return const SuperlikeTorchBadge(
                                                  size: TorchBadgeSize.medium,
                                                  showBackground: true,
                                                );
                                              },
                                            ),
                                          ),
                                          if (isCurrent)
                                            Positioned(
                                              right: 12,
                                              bottom: 12,
                                              child: GestureDetector(
                                                behavior: HitTestBehavior.opaque,
                                                onTap: () => _toggleVideoMode(_currentEffectivePosition()),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xE6141414),
                                                    borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                                                    border: Border.all(
                                                      color: Colors.white.withOpacity(0.24),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if (_isVideoLoading) ...[
                                                        const SizedBox(
                                                          width: 12,
                                                          height: 12,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 7),
                                                        const Text(
                                                          "Chargement...",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 11.5,
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                      ] else ...[
                                                        Container(
                                                          padding: const EdgeInsets.all(3.5),
                                                          decoration: BoxDecoration(
                                                            color: colorScheme.primary,
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: const Icon(
                                                            Icons.play_arrow_rounded,
                                                            color: Colors.white,
                                                            size: 13,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 7),
                                                        const Text(
                                                          "Voir le clip",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 11.5,
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Center(
                        child: SizedBox(
                          width: coverSize,
                          height: coverSize,
                          child: SuperlikeBurstOverlay(key: _burstKey),
                        ),
                      ),
                      if (state.isFreeLyricsMode &&
                          state.currentLyrics != null &&
                          state.currentLyrics!.hasSynced)
                        _buildLivePositionBuilder(
                          builder: (context, livePos) {
                            final currentLine = _resolveSyncedLyricLine(state, livePos);
                            if (currentLine.isEmpty) return const SizedBox.shrink();
                            return Positioned(
                              left: 24,
                              right: 24,
                              bottom: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.68),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                                ),
                                child: Text(
                                  currentLine,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colorScheme.tertiary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                PlayerTrackInfo(
                  title: track.title,
                  artistName: track.artistName,
                ),
                const SizedBox(height: 12),
                BlocBuilder<SuperlikeCubit, SuperlikeState>(
                  builder: (context, slState) {
                    final isSuper = slState.isSuperliked(track.id);
                    return _buildLivePositionBuilder(
                      builder: (context, livePos) => PlayerProgressBar(
                        key: ValueKey('progress_${track.id}_$isSuper'),
                        position: livePos,
                        duration: duration,
                        isSuperliked: isSuper,
                        onSeek: _seekTo,
                        trailing: PlayerFavoriteButton(track: track),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                PlayerPrimaryControls(
                  isPlaying: isPlaying,
                  isBuffering: !_isVideoMode && state.isBuffering,
                  isShuffleModeEnabled: state.isShuffleModeEnabled,
                  loopMode: state.loopMode,
                  onPlayPause: _togglePlayPause,
                  onPrevious: () => context.read<PlayerCubit>().playPrevious(),
                  onNext: () => context.read<PlayerCubit>().playNext(),
                  onShuffle: () => context.read<PlayerCubit>().toggleShuffle(),
                  onRepeat: () => context.read<PlayerCubit>().toggleRepeat(),
                ),
                const SizedBox(height: 12),
                PlayerSecondaryControls(
                  currentTrack: track,
                  onQueueTapped: _openQueueSheet,
                  onLyricsTapped: _openLyricsScreen,
                  onKaraokeTapped: _openKaraokePartyScreen,
                  onDownloadTapped: () => _showDownloadSnackBar(track),
                ),
                const SizedBox(height: 8),
                const PlayerAudioDeviceChip(),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withOpacity(0.55),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Découvrez des sons similaires",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.60),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildSimilarTracksSection(track, isSpecial: false),
        ],
      ),
    );
  }

  Widget _buildSimilarTracksSection(
    TrackModel currentTrack, {
    required bool isSpecial,
    Color? backgroundColor,
  }) {
    final double thumbSize = isSpecial ? 64.0 : 50.0;
    final double titleFontSize = isSpecial ? 17.5 : 15.0;
    final double artistFontSize = isSpecial ? 14.5 : 13.0;

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        color: backgroundColor ?? (isSpecial ? const Color(0xFF0F0F0F) : Colors.transparent),
        padding: const EdgeInsets.only(top: 10, bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isSpecial ? AppColors.primary.withValues(alpha: 0.45) : Colors.white.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.explore_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Découvrez des sons similaires",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSpecial ? 22 : 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "Inspiré de ${currentTrack.artistName} • ${_similarTracks.length} titres",
                        style: TextStyle(
                          color: Colors.white.withOpacity(isSpecial ? 0.78 : 0.65),
                          fontSize: isSpecial ? 14 : 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_isLoadingSimilar)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else if (_similarTracks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
              child: Center(
                child: Text(
                  "Recherche de sons similaires en cours...",
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: _similarTracks.length,
              separatorBuilder: (_, __) => Divider(
                color: Colors.white.withOpacity(0.12),
                height: 1,
                indent: isSpecial ? 78 : 64,
                endIndent: 8,
              ),
              itemBuilder: (context, index) {
                final sTrack = _similarTracks[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onLongPress: () => TrackContextMenu.show(context, sTrack),
                    onTap: () {
                      context.read<PlayerCubit>().playTrack(
                        sTrack,
                        queue: _similarTracks,
                        source: "Découvrez des sons similaires",
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: isSpecial ? 11.0 : 9.0,
                        horizontal: 6.0,
                      ),
                      child: Row(
                        children: [
                          SonoritizArtwork(
                            imageUrl: sTrack.coverUrl,
                            width: thumbSize,
                            height: thumbSize,
                            borderRadius: isSpecial ? 13 : 10,
                            cacheMaxDimension: 160,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sTrack.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: titleFontSize,
                                    fontWeight: isSpecial ? FontWeight.w800 : FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sTrack.artistName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(isSpecial ? 0.85 : 0.70),
                                    fontSize: artistFontSize,
                                    fontWeight: isSpecial ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.play_arrow_rounded,
                              color: isSpecial ? AppColors.primary : Colors.white,
                              size: isSpecial ? 28 : 25,
                            ),
                            onPressed: () {
                              context.read<PlayerCubit>().playTrack(
                                sTrack,
                                queue: _similarTracks,
                                source: "Découvrez des sons similaires",
                              );
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: "Options",
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white.withValues(alpha: 0.72),
                              size: 21,
                            ),
                            onPressed: () => TrackContextMenu.show(context, sTrack),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      ),
    );
  }
}
