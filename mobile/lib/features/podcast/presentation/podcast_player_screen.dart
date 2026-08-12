import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/artist_name_display.dart';
import '../../player/data/models/track_model.dart';

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
  bool _isVideoMode = false;
  bool _isPlaying = false;
  bool _isLiked = false;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(widget.track.id);
      // On prend un flux muxed (video + audio) pour pouvoir basculer facilement
      final streamInfo = manifest.muxed.withHighestBitrate();
      
      _controller = VideoPlayerController.networkUrl(streamInfo.url);
      await _controller!.initialize();
      _controller!.play();
      _controller!.addListener(_playerListener);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = true;
        });
      }
    } catch (e) {
      print('Erreur init podcast: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _playerListener() {
    if (!mounted) return;
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
    // Restaurer l'orientation
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _forward15s() {
    if (_controller == null) return;
    final currentPosition = _controller!.value.position;
    _controller!.seekTo(currentPosition + const Duration(seconds: 15));
  }
  
  void _rewind15s() {
    if (_controller == null) return;
    final currentPosition = _controller!.value.position;
    _controller!.seekTo(currentPosition - const Duration(seconds: 15));
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
        // Mode plein écran vidéo (peut être horizontal ou vertical selon le format, par défaut on laisse libre)
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
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    )
                  : const CircularProgressIndicator(color: AppColors.primary),
            ),
            // Contrôles superposés
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
                  IconButton(icon: const Icon(Icons.replay, color: Colors.white, size: 40), onPressed: _rewind15s),
                  const SizedBox(width: 32),
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: AppColors.primary, size: 64),
                    onPressed: _togglePlayPause,
                  ),
                  const SizedBox(width: 32),
                  IconButton(icon: const Icon(Icons.forward_30, color: Colors.white, size: 40), onPressed: _forward15s),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Podcast", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? AppColors.primary : Colors.white),
            onPressed: () => setState(() => _isLiked = !_isLiked),
          ),
          IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: _isVideoMode && _controller != null && _controller!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl: widget.track.coverUrl,
                              width: MediaQuery.of(context).size.width * 0.8,
                              height: MediaQuery.of(context).size.width * 0.8,
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    children: [
                      Text(
                        widget.track.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      ArtistNameDisplay(
                        artistName: widget.track.artistName,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                      ),
                      const SizedBox(height: 32),
                      
                      // Progress Bar
                      if (_controller != null)
                        ValueListenableBuilder(
                          valueListenable: _controller!,
                          builder: (context, VideoPlayerValue value, child) {
                            return Column(
                              children: [
                                SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    activeTrackColor: AppColors.primary,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: AppColors.primary,
                                  ),
                                  child: Slider(
                                    value: value.position.inSeconds.toDouble(),
                                    max: value.duration.inSeconds.toDouble() > 0 ? value.duration.inSeconds.toDouble() : 1,
                                    onChanged: (v) {
                                      _controller!.seekTo(Duration(seconds: v.toInt()));
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatDuration(value.position), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                      Text(_formatDuration(value.duration), style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
                          IconButton(icon: const Icon(Icons.file_download_outlined, color: Colors.white), onPressed: () {}),
                          IconButton(icon: const Icon(Icons.replay, color: Colors.white, size: 36), onPressed: _rewind15s),
                          Container(
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            child: IconButton(
                              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40),
                              onPressed: _togglePlayPause,
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.forward_30, color: Colors.white, size: 36), onPressed: _forward15s),
                          IconButton(
                            icon: Icon(_isVideoMode ? Icons.videocam : Icons.videocam_off, color: _isVideoMode ? AppColors.primary : Colors.white),
                            onPressed: _toggleVideoMode,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isVideoMode)
                        TextButton.icon(
                          onPressed: _toggleFullScreen,
                          icon: const Icon(Icons.fullscreen, color: Colors.white70),
                          label: const Text("Plein Écran", style: TextStyle(color: Colors.white70)),
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
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
