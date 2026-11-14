import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/services/palette_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../../features/library/presentation/cubit/library_cubit.dart';
import '../../../../features/library/presentation/cubit/library_state.dart';
import '../../../../features/player/data/models/track_model.dart';
import '../../../../features/player/presentation/cubit/player_cubit.dart';
import '../../../../features/player/presentation/widgets/player_components/immersive_player_widgets.dart';
import 'short_mini_player_widget.dart';

class VideoShortWidget extends StatefulWidget {
  final TrackModel track;
  final bool isMuted;
  final bool isActive;
  final VoidCallback? onAutoScrollTriggered;

  const VideoShortWidget({
    Key? key,
    required this.track,
    required this.isMuted,
    required this.isActive,
    this.onAutoScrollTriggered,
  }) : super(key: key);

  @override
  State<VideoShortWidget> createState() => _VideoShortWidgetState();
}

class _VideoShortWidgetState extends State<VideoShortWidget> {
  VideoPlayerController? _videoPlayerController;
  final YoutubeExplode _yt = YoutubeExplode();

  bool _initialized = false;
  bool _isInitializing = false;
  bool _isPlaying = false;
  bool _isLoading = true;
  double _progress = 0.0;
  bool _showHeart = false;
  ImmersivePalette _palette = ImmersivePalette.fallback;

  @override
  void initState() {
    super.initState();
    _loadPalette();
    if (widget.isActive) {
      _initVideo();
    }
  }

  Future<void> _loadPalette() async {
    final pal = await PaletteService.getPalette(widget.track.coverUrl);
    if (mounted) {
      setState(() => _palette = pal);
    }
  }

  @override
  void didUpdateWidget(covariant VideoShortWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMuted != oldWidget.isMuted) {
      _videoPlayerController?.setVolume(widget.isMuted ? 0.0 : 1.0);
    }
    if (widget.track.coverUrl != oldWidget.track.coverUrl) {
      _loadPalette();
    }
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (!_initialized && !_isInitializing) {
          _initVideo();
        } else {
          _videoPlayerController?.play();
          setState(() => _isPlaying = true);
        }
      } else {
        _videoPlayerController?.pause();
        setState(() => _isPlaying = false);
      }
    }
  }

  Future<void> _initVideo() async {
    if (_isInitializing || _initialized) return;
    _isInitializing = true;

    try {
      String videoId = widget.track.id;
      if (videoId.startsWith('deezer_') ||
          !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId)) {
        final results = await _yt.search.search(
            '${widget.track.artistName} ${widget.track.title} official video');
        if (results.isNotEmpty) {
          videoId = results.first.id.value;
        }
      }

      StreamManifest manifest;
      try {
        manifest = await _yt.videos.streamsClient.getManifest(
          videoId,
          ytClients: [YoutubeApiClient.androidSdkless],
          requireWatchPage: false,
        );
      } catch (_) {
        manifest = await _yt.videos.streamsClient.getManifest(videoId);
      }

      String videoUrl = '';
      if (manifest.muxed.isNotEmpty) {
        videoUrl = manifest.muxed.withHighestBitrate().url.toString();
      }

      if (videoUrl.isEmpty || !mounted) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final ctrl = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      _videoPlayerController = ctrl;
      await _videoPlayerController!.setVolume(widget.isMuted ? 0.0 : 1.0);
      _initialized = true;

      setState(() => _isLoading = false);
      if (widget.isActive) {
        _videoPlayerController!.play();
        setState(() => _isPlaying = true);
      }

      _videoPlayerController!.addListener(() {
        if (!mounted || _videoPlayerController == null) return;
        final pos = _videoPlayerController!.value.position;
        final seconds = pos.inMilliseconds / 1000.0;

        if (seconds >= 20.0) {
          _videoPlayerController!.seekTo(Duration.zero);
          if (widget.isActive && _isPlaying) {
            _videoPlayerController!.play();
          }
          widget.onAutoScrollTriggered?.call();
        } else {
          setState(() {
            _progress = (seconds / 20.0).clamp(0.0, 1.0);
          });
        }
      });
    } catch (e) {
      debugPrint("Erreur vidéo short: $e");
      if (mounted) setState(() => _isLoading = false);
    } finally {
      _isInitializing = false;
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _yt.close();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_videoPlayerController == null) return;
    if (_isPlaying) {
      _videoPlayerController!.pause();
    } else {
      context.read<PlayerCubit>().pause();
      _videoPlayerController!.play();
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _triggerHeartAnimation() {
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _handleLike() {
    final libraryCubit = context.read<LibraryCubit>();
    if (libraryCubit.isFavorite(widget.track.id)) {
      libraryCubit.removeFavorite(widget.track.id);
    } else {
      libraryCubit.addFavorite(widget.track);
      _triggerHeartAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _palette.accentColor;

    return GestureDetector(
      onDoubleTap: _handleLike,
      onTap: _togglePlayPause,
      child: Stack(
        children: [
          // 1. Fond flouté dynamique éliminant les bandes noires des clips 16:9
          Positioned.fill(
            child: widget.track.coverUrl.isNotEmpty
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Transform.scale(
                        scale: 1.3,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
                          child: Opacity(
                            opacity: 0.45,
                            child: SonoritizArtwork(
                              imageUrl: widget.track.coverUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ],
                  )
                : Container(color: Colors.black),
          ),

          // 2. Flux Vidéo net centré
          Positioned.fill(
            child: _isLoading || _videoPlayerController == null
                ? Center(
                    child: CircularProgressIndicator(color: accent),
                  )
                : Center(
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.25),
                            blurRadius: 32,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: AspectRatio(
                        aspectRatio: _videoPlayerController!.value.aspectRatio > 0
                            ? _videoPlayerController!.value.aspectRatio
                            : 9 / 16,
                        child: VideoPlayer(_videoPlayerController!),
                      ),
                    ),
                  ),
          ),

          // 3. Boutons d'actions latérales dépolis
          Positioned(
            right: 16,
            bottom: 120,
            child: BlocBuilder<LibraryCubit, LibraryState>(
              builder: (context, state) {
                final isFav =
                    context.read<LibraryCubit>().isFavorite(widget.track.id);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGlassActionBtn(
                      icon: isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      iconColor: isFav ? AppColors.primary : Colors.white,
                      onTap: _handleLike,
                      tooltip: "Aimer cette vidéo",
                    ),
                    const SizedBox(height: 14),
                    _buildGlassActionBtn(
                      icon: Icons.open_in_full_rounded,
                      iconColor: Colors.white,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _videoPlayerController?.pause();
                        setState(() => _isPlaying = false);
                        context.read<PlayerCubit>().playTrack(
                              widget.track,
                              source: 'Sonorités vidéo',
                            );
                        context.push('/fullscreen');
                      },
                      tooltip: "Écouter en entier",
                    ),
                  ],
                );
              },
            ),
          ),

          // 4. Dock Lecteur Signature au bas de l'écran
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: ShortMiniPlayerWidget(
              track: widget.track,
              isPlaying: _isPlaying,
              progress: _progress,
              onPlayPause: _togglePlayPause,
              onOpenFullPlayer: () {
                _videoPlayerController?.pause();
                setState(() => _isPlaying = false);
                context.read<PlayerCubit>().playTrack(
                      widget.track,
                      source: 'Sonorités vidéo',
                    );
                context.push('/fullscreen');
              },
              progressColor: accent,
            ),
          ),

          // 5. Animation du Super Coeur sur double-tap
          if (_showHeart)
            Center(
              child: const Icon(Icons.favorite_rounded,
                      color: AppColors.primary, size: 128)
                  .animate()
                  .scale(duration: 320.ms, curve: Curves.easeOutBack)
                  .fadeOut(delay: 500.ms, duration: 280.ms),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassActionBtn({
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF141215).withValues(alpha: 0.65),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
