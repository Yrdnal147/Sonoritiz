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
import '../../../../features/player/data/models/lyrics_model.dart';
import '../../../../features/player/data/services/lyrics_service.dart';
import 'short_mini_player_widget.dart';

class LyricsShortWidget extends StatefulWidget {
  final TrackModel track;
  final bool isMuted;
  final bool isActive;
  final VoidCallback? onAutoScrollTriggered;

  const LyricsShortWidget({
    Key? key,
    required this.track,
    required this.isMuted,
    required this.isActive,
    this.onAutoScrollTriggered,
  }) : super(key: key);

  @override
  State<LyricsShortWidget> createState() => _LyricsShortWidgetState();
}

class _LyricsShortWidgetState extends State<LyricsShortWidget> {
  late AudioPlayer _audioPlayer;
  final YoutubeExplode _yt = YoutubeExplode();
  final LyricsService _lyricsService = LyricsService();
  
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

  LyricsModel? _lyrics;
  int _currentLyricsIndex = -1;
  List<Map<String, dynamic>> _parsedLyrics = [];

  @override
  void initState() {
    super.initState();
    _bgColor = _dynamicColors[Random().nextInt(_dynamicColors.length)];
    _audioPlayer = AudioPlayer();
    _fetchLyrics();
    _initAudio(); // Unconditional to allow preloading
  }

  @override
  void didUpdateWidget(covariant LyricsShortWidget oldWidget) {
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

  Future<void> _fetchLyrics() async {
    final lyrics = await _lyricsService.getLyrics(widget.track.id, widget.track.artistName, widget.track.title, widget.track.durationSeconds);
    if (mounted && lyrics != null) {
      setState(() {
        _lyrics = lyrics;
        if (lyrics.syncedLyrics != null && lyrics.syncedLyrics!.isNotEmpty) {
          _parsedLyrics = _parseSyncedLyrics(lyrics.syncedLyrics!);
        }
      });
    }
  }

  List<Map<String, dynamic>> _parseSyncedLyrics(String lrc) {
    final lines = lrc.split('\n');
    final RegExp timeRegExp = RegExp(r'\[(\d{2}):(\d{2}\.\d{2,3})\]');
    List<Map<String, dynamic>> parsed = [];

    for (var line in lines) {
      final match = timeRegExp.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = double.parse(match.group(2)!);
        final timeInMs = (minutes * 60 * 1000) + (seconds * 1000).toInt();
        final text = line.substring(match.end).trim();
        if (text.isNotEmpty) {
          parsed.add({'time': timeInMs, 'text': text});
        }
      }
    }
    return parsed;
  }

  Future<void> _initAudio() async {
    try {
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

      _positionSub = _audioPlayer.positionStream.listen((pos) {
        if (!mounted) return;
        
        final ms = pos.inMilliseconds;
        final seconds = ms / 1000.0;
        
        if (seconds >= 20.0) {
          _audioPlayer.seek(Duration.zero);
          if (widget.isActive && _isPlaying) {
             _audioPlayer.play();
          }
          setState(() {
            _currentLyricsIndex = -1;
          });
          if (widget.onAutoScrollTriggered != null) {
            widget.onAutoScrollTriggered!();
          }
        } else {
          // Sync lyrics
          if (_parsedLyrics.isNotEmpty) {
            int newIndex = -1;
            for (int i = 0; i < _parsedLyrics.length; i++) {
              if (ms >= _parsedLyrics[i]['time']) {
                newIndex = i;
              } else {
                break;
              }
            }
            if (newIndex != _currentLyricsIndex) {
              setState(() {
                _currentLyricsIndex = newIndex;
              });
            }
          }

          setState(() {
            _progress = seconds / 20.0;
          });
        }
      });

    } catch (e) {
      print("Erreur audio lyrics short: $e");
      if (mounted) setState(() => _isLoading = false);
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
        
        // Center content
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
                  // Overlay Dark for Lyrics
                  Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.black54, // Dim the cover slightly so lyrics pop
                    ),
                  ),
                  // Lyrics View overlayed on top of the circle
                  SizedBox(
                    width: 300,
                    height: 350,
                    child: _buildLyricsView(),
                  ),
                ],
              ),
        ),

        // Mini player at bottom
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

  Widget _buildLyricsView() {
    if (_parsedLyrics.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.0),
        child: Text(
          "Paroles non disponibles pour ce morceau.",
          style: TextStyle(color: Colors.white54, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      );
    }

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(), // Managed by auto-scroll basically (or just centered)
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_parsedLyrics.length, (index) {
            final isCurrent = index == _currentLyricsIndex;
            final isPast = index < _currentLyricsIndex;
            
            // Only show lyrics roughly around the current index
            if ((index - _currentLyricsIndex).abs() > 3) return const SizedBox.shrink();

            return AnimatedContainer(
              duration: 300.ms,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _parsedLyrics[index]['text'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isCurrent 
                      ? Colors.white 
                      : (isPast ? Colors.white38 : Colors.white24),
                  fontSize: isCurrent ? 26 : 20,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
