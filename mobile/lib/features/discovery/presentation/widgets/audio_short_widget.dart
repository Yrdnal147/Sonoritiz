import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/library/presentation/cubit/library_cubit.dart';
import '../../../../features/library/presentation/cubit/library_state.dart';
import '../../../../features/player/data/models/track_model.dart';
import 'short_mini_player_widget.dart';
import 'dart:math' as math;

class AudioShortWidget extends StatefulWidget {
  final TrackModel track;
  final bool isMuted;
  final bool isActive;
  final VoidCallback? onAutoScrollTriggered;

  const AudioShortWidget({
    Key? key,
    required this.track,
    required this.isMuted,
    required this.isActive,
    this.onAutoScrollTriggered,
  }) : super(key: key);

  @override
  State<AudioShortWidget> createState() => _AudioShortWidgetState();
}

class _AudioShortWidgetState extends State<AudioShortWidget> {
  late AudioPlayer _audioPlayer;
  final YoutubeExplode _yt = YoutubeExplode();
  
  bool _isPlaying = false;
  bool _isLoading = true;
  double _progress = 0.0;
  bool _showHeart = false;
  
  StreamSubscription? _positionSub;
  late Color _bgColor;

  static const List<Color> _dynamicColors = [
    Color(0xFFC1121F), Color(0xFFC32F27), Color(0xFF087E8B), Color(0xFFE28413),
    Color(0xFFFF006E), Color(0xFF8338EC), Color(0xFF1BE7FF), Color(0xFF263C41),
    Color(0xFF2B9348), Color(0xFFFE6A86), Color(0xFF47026C), Color(0xFF9EF01A),
    Color(0xFF08A045), Color(0xFFF17F29), Color(0xFF0A369D),
  ];

  @override
  void initState() {
    super.initState();
    _bgColor = _dynamicColors[Random().nextInt(_dynamicColors.length)];
    _audioPlayer = AudioPlayer();
    _initAudio(); // Unconditional to allow preloading
  }

  @override
  void didUpdateWidget(covariant AudioShortWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMuted != oldWidget.isMuted) {
      _audioPlayer.setVolume(widget.isMuted ? 0.0 : 1.0);
    }
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (_isLoading && _progress == 0.0 && !_isPlaying) {
          _initAudio();
        } else {
          _audioPlayer.play();
          setState(() => _isPlaying = true);
        }
      } else {
        _audioPlayer.pause();
        setState(() => _isPlaying = false);
      }
    }
  }

  Future<void> _initAudio() async {
    try {
      // Fetch stream
      final manifest = await _yt.videos.streamsClient.getManifest(widget.track.id);
      String audioUrl = '';
      String fallbackUrl = '';
      
      if (manifest.audioOnly.isNotEmpty) {
        audioUrl = manifest.audioOnly.withHighestBitrate().url.toString();
        if (manifest.muxed.isNotEmpty) {
          fallbackUrl = manifest.muxed.sortByVideoQuality().first.url.toString();
        }
      } else if (manifest.muxed.isNotEmpty) {
        audioUrl = manifest.muxed.sortByVideoQuality().first.url.toString();
      }

      if (audioUrl.isEmpty) return;

      try {
        await _audioPlayer.setUrl(audioUrl);
      } catch (e) {
        if (fallbackUrl.isNotEmpty) {
          await _audioPlayer.setUrl(fallbackUrl);
        } else {
          rethrow;
        }
      }
      
      await _audioPlayer.setVolume(widget.isMuted ? 0.0 : 1.0);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (widget.isActive) {
          _audioPlayer.play();
          setState(() => _isPlaying = true);
        }
      }

      // Loop after 20 seconds
      _positionSub = _audioPlayer.positionStream.listen((pos) {
        if (!mounted) return;
        
        final seconds = pos.inMilliseconds / 1000.0;
        if (seconds >= 20.0) {
          _audioPlayer.seek(Duration.zero);
          if (widget.isActive && _isPlaying) {
             _audioPlayer.play();
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
      print("Erreur audio short: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _audioPlayer.dispose();
    _yt.close();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
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
          // Solid random color background
          Positioned.fill(
          child: Container(
            color: _bgColor,
          ),
        ),
        
        // Center content (higher and bigger)
        Align(
          alignment: const Alignment(0, -0.2),
          child: _isLoading 
            ? const CircularProgressIndicator(color: Colors.white)
            : Stack(
                alignment: Alignment.center,
                children: [
                  // Cover
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: widget.track.coverUrl,
                      width: 300,
                      height: 300,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
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
              _audioPlayer.pause();
              setState(() => _isPlaying = false);
            },
            progressColor: _bgColor,
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
                      // We can open the add to playlist bottom sheet here
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
