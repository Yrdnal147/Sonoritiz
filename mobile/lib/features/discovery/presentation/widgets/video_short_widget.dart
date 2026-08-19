import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/library/presentation/cubit/library_cubit.dart';
import '../../../../features/library/presentation/cubit/library_state.dart';
import '../../../../features/player/data/models/track_model.dart';
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
  
  bool _isPlaying = false;
  bool _isLoading = true;
  double _progress = 0.0;
  bool _showHeart = false;
  
  @override
  void initState() {
    super.initState();
    _initVideo(); // Unconditional to allow preloading
  }

  @override
  void didUpdateWidget(covariant VideoShortWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMuted != oldWidget.isMuted) {
      _videoPlayerController?.setVolume(widget.isMuted ? 0.0 : 1.0);
    }
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (_videoPlayerController == null && _isLoading && _progress == 0.0) {
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
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(widget.track.id);
      String videoUrl = '';
      if (manifest.muxed.isNotEmpty) {
        try {
          videoUrl = manifest.muxed.sortByVideoQuality().first.url.toString();
        } catch(e) {
          videoUrl = manifest.muxed.first.url.toString();
        }
      }

      if (videoUrl.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return; // Handle error UI if needed
      }

      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoPlayerController!.initialize();
      await _videoPlayerController!.setVolume(widget.isMuted ? 0.0 : 1.0);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (widget.isActive) {
          _videoPlayerController!.play();
          setState(() => _isPlaying = true);
        }
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
          if (widget.onAutoScrollTriggered != null) {
            widget.onAutoScrollTriggered!();
          }
        } else {
          setState(() {
            _progress = seconds / 20.0;
          });
        }
      });

    } catch (e) {
      print("Erreur vidéo short: $e");
      if (mounted) setState(() => _isLoading = false);
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
      _videoPlayerController!.play();
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _triggerHeartAnimation() {
    setState(() {
      _showHeart = true;
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _showHeart = false;
        });
      }
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
    return GestureDetector(
      onDoubleTap: _handleLike,
      child: Stack(
        children: [
          // Black background to prevent white flashes for contain fit
          Positioned.fill(
            child: Container(color: Colors.black),
          ),
          // Video content
          Positioned.fill(
            child: _isLoading || _videoPlayerController == null
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Center(
                  child: AspectRatio(
                    aspectRatio: _videoPlayerController!.value.aspectRatio,
                    child: VideoPlayer(_videoPlayerController!),
                  ),
                ),
          ),


        // Mini player at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 24, // above navigation bar
          child: ShortMiniPlayerWidget(
            track: widget.track,
            isPlaying: _isPlaying,
            progress: _progress,
            onPlayPause: _togglePlayPause,
            onOpenFullPlayer: () {
              _videoPlayerController?.pause();
              setState(() => _isPlaying = false);
            },
            progressColor: AppColors.primary,
          ),
        ),

        // Floating Action Buttons (Right)
        Positioned(
          right: 16,
          bottom: 120,
          child: BlocBuilder<LibraryCubit, LibraryState>(
            builder: (context, state) {
              final isFav = context.read<LibraryCubit>().isFavorite(widget.track.id);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? AppColors.primary : Colors.white,
                      size: 32,
                    ),
                    onPressed: _handleLike,
                  ),
                  const SizedBox(height: 16),
                  IconButton(
                    icon: const Icon(Icons.playlist_add_rounded, color: Colors.white, size: 32),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajout à la playlist')));
                    },
                  ),
                ],
              );
            },
          ),
        ),

        // Big Heart Animation
        if (_showHeart)
          Center(
            child: const Icon(Icons.favorite, color: AppColors.primary, size: 120)
                .animate()
                .scale(duration: 300.ms, curve: Curves.easeOutBack)
                .fadeOut(delay: 500.ms, duration: 300.ms),
          ),
      ],
    ),
    );
  }
}
