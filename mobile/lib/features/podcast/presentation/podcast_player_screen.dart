import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/share_utils.dart';
import '../../../../core/widgets/artist_name_display.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../../core/widgets/sonoritiz_page_title.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';

class PodcastPlayerScreen extends StatefulWidget {
  final TrackModel track;

  const PodcastPlayerScreen({Key? key, required this.track}) : super(key: key);

  @override
  State<PodcastPlayerScreen> createState() => _PodcastPlayerScreenState();
}

class _PodcastPlayerScreenState extends State<PodcastPlayerScreen> {
  VideoPlayerController? _controller;
  final YoutubeExplode _yt = YoutubeExplode();
  bool _isLoading = true;
  bool _hasError = false;
  bool _isVideoMode = false;
  bool _isPlaying = false;
  bool _isLiked = false;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PlayerCubit>().pause();
      }
    });
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    try {
      String videoId = widget.track.id;
      if (videoId.startsWith('deezer_') ||
          !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId)) {
        final isBook = widget.track.genre.toLowerCase().contains('livre');
        final query = isBook
            ? '${widget.track.title} ${widget.track.artistName} livre audio complet'
            : '${widget.track.title} ${widget.track.artistName} podcast épisode';
        final results = await _yt.search.search(query);
        if (results.isNotEmpty) {
          videoId = results.first.id.value;
        } else {
          throw Exception('Aucun flux trouvé pour ce contenu');
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

      Uri? streamUri;
      if (manifest.muxed.isNotEmpty) {
        streamUri = manifest.muxed.withHighestBitrate().url;
      } else if (manifest.audioOnly.isNotEmpty) {
        streamUri = manifest.audioOnly.withHighestBitrate().url;
      }

      if (streamUri == null) {
        throw Exception('Aucun flux audio/vidéo disponible');
      }

      final ctrl = VideoPlayerController.networkUrl(streamUri);
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      _controller = ctrl;
      _controller!.addListener(_playerListener);
      await _controller!.play();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = true;
        });
      }
    } catch (e) {
      debugPrint('Erreur init podcast: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _playerListener() {
    if (!mounted || _controller == null) return;
    if (_controller!.value.isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = _controller!.value.isPlaying;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_playerListener);
    _controller?.dispose();
    _yt.close();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      context.read<PlayerCubit>().pause();
      _controller!.play();
    }
  }

  void _forward15s() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final dur = _controller!.value.duration;
    final target = _controller!.value.position + const Duration(seconds: 15);
    _controller!.seekTo(target > dur ? dur : target);
  }

  void _rewind15s() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final target = _controller!.value.position - const Duration(seconds: 15);
    _controller!.seekTo(target < Duration.zero ? Duration.zero : target);
  }

  void _toggleVideoMode() {
    setState(() {
      _isVideoMode = !_isVideoMode;
    });
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
          DeviceOrientation.portraitUp,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen && _isVideoMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: _controller != null && _controller!.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio > 0
                          ? _controller!.value.aspectRatio
                          : 16 / 9,
                      child: VideoPlayer(_controller!),
                    )
                  : const CircularProgressIndicator(color: AppColors.primary),
            ),
            Positioned(
              top: 40,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: _toggleFullScreen,
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.replay_10_rounded, color: Colors.white, size: 40),
                    onPressed: _rewind15s,
                  ),
                  const SizedBox(width: 32),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 38,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                  ),
                  const SizedBox(width: 32),
                  IconButton(
                    icon: const Icon(Icons.forward_30_rounded,
                        color: Colors.white, size: 40),
                    onPressed: _forward15s,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final coverSize = MediaQuery.of(context).size.width * 0.78;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: SonoritizPageTitle(
          title: widget.track.genre.toLowerCase().contains('livre')
              ? "Livre Audio"
              : "Podcast",
          fontSize: 21,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: _isLiked ? AppColors.primary : Colors.white,
            ),
            onPressed: () => setState(() => _isLiked = !_isLiked),
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => ShareUtils.shareTrack(widget.track),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.white54, size: 52),
                        const SizedBox(height: 16),
                        const Text(
                          "Impossible de charger cet épisode pour le moment.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _initPlayer,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text("Réessayer"),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: _isVideoMode &&
                                _controller != null &&
                                _controller!.value.isInitialized
                            ? AspectRatio(
                                aspectRatio: _controller!.value.aspectRatio > 0
                                    ? _controller!.value.aspectRatio
                                    : 16 / 9,
                                child: VideoPlayer(_controller!),
                              )
                            : SonoritizArtwork(
                                imageUrl: widget.track.coverUrl,
                                width: coverSize,
                                height: coverSize,
                                borderRadius: 20,
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        children: [
                          Text(
                            widget.track.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          ArtistNameDisplay(
                            artistName: widget.track.artistName,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Progress Bar (protégée par .clamp)
                          if (_controller != null)
                            ValueListenableBuilder(
                              valueListenable: _controller!,
                              builder:
                                  (context, VideoPlayerValue value, child) {
                                final double maxSec =
                                    value.duration.inSeconds > 0
                                        ? value.duration.inSeconds.toDouble()
                                        : 1.0;
                                final double curSec = value.position.inSeconds
                                    .toDouble()
                                    .clamp(0.0, maxSec);

                                return Column(
                                  children: [
                                    SliderTheme(
                                      data: const SliderThemeData(
                                        trackHeight: 4,
                                        thumbShape: RoundSliderThumbShape(
                                            enabledThumbRadius: 6),
                                        activeTrackColor: AppColors.primary,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: AppColors.primary,
                                      ),
                                      child: Slider(
                                        value: curSec,
                                        min: 0.0,
                                        max: maxSec,
                                        onChanged: (v) {
                                          _controller!.seekTo(
                                              Duration(seconds: v.toInt()));
                                        },
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(value.position),
                                            style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12),
                                          ),
                                          Text(
                                            _formatDuration(value.duration),
                                            style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                          const SizedBox(height: 24),

                          // Main Controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.replay_10_rounded,
                                    color: Colors.white, size: 36),
                                onPressed: _rewind15s,
                              ),
                              Container(
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    _isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.black,
                                    size: 40,
                                  ),
                                  onPressed: _togglePlayPause,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.forward_30_rounded,
                                    color: Colors.white, size: 36),
                                onPressed: _forward15s,
                              ),
                              IconButton(
                                icon: Icon(
                                  _isVideoMode
                                      ? Icons.videocam
                                      : Icons.videocam_off,
                                  color: _isVideoMode
                                      ? AppColors.primary
                                      : Colors.white,
                                ),
                                onPressed: _toggleVideoMode,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_isVideoMode)
                            TextButton.icon(
                              onPressed: _toggleFullScreen,
                              icon: const Icon(Icons.fullscreen,
                                  color: Colors.white70),
                              label: const Text("Plein Écran",
                                  style: TextStyle(color: Colors.white70)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
