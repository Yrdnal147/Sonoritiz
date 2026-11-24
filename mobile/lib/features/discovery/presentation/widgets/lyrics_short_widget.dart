import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/services/palette_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/artist_name_display.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../../features/library/presentation/cubit/library_cubit.dart';
import '../../../../features/library/presentation/cubit/library_state.dart';
import '../../../../features/player/data/models/track_model.dart';
import '../../../../features/player/data/models/lyrics_model.dart';
import '../../../../features/player/data/services/lyrics_service.dart';
import '../../../../features/player/presentation/cubit/player_cubit.dart';
import '../../../../features/player/presentation/widgets/player_components/immersive_player_widgets.dart';
import 'short_mini_player_widget.dart';

class LyricsShortWidget extends StatefulWidget {
  final TrackModel track;
  final bool isMuted;
  final bool isActive;
  final VoidCallback? onAutoScrollTriggered;
  final int clipDurationSeconds;
  final bool focusHighlight;

  const LyricsShortWidget({
    Key? key,
    required this.track,
    required this.isMuted,
    required this.isActive,
    this.onAutoScrollTriggered,
    this.clipDurationSeconds = 20,
    this.focusHighlight = false,
  }) : super(key: key);

  @override
  State<LyricsShortWidget> createState() => _LyricsShortWidgetState();
}

class _LyricsShortWidgetState extends State<LyricsShortWidget> {
  AudioPlayer? _audioPlayer;
  final YoutubeExplode _yt = YoutubeExplode();
  final LyricsService _lyricsService = LyricsService();

  bool _initialized = false;
  bool _isInitializing = false;
  bool _isPlaying = false;
  bool _isLoading = true;
  double _progress = 0.0;
  bool _showHeart = false;
  int _highlightStartSeconds = 0;

  StreamSubscription? _positionSub;
  ImmersivePalette _palette = ImmersivePalette.fallback;

  LyricsModel? _lyrics;
  int _currentLyricsIndex = -1;
  List<Map<String, dynamic>> _parsedLyrics = [];
  final ScrollController _lyricsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPalette();
    if (widget.isActive) {
      _fetchLyrics();
      _initAudio();
    }
  }

  Future<void> _loadPalette() async {
    final pal = await PaletteService.getPalette(widget.track.coverUrl);
    if (mounted) {
      setState(() => _palette = pal);
    }
  }

  @override
  void didUpdateWidget(covariant LyricsShortWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMuted != oldWidget.isMuted) {
      _audioPlayer?.setVolume(widget.isMuted ? 0.0 : 1.0);
    }
    if (widget.track.coverUrl != oldWidget.track.coverUrl) {
      _loadPalette();
    }
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (_lyrics == null) _fetchLyrics();
        if (!_initialized && !_isInitializing) {
          _initAudio();
        } else {
          _audioPlayer?.play();
          setState(() => _isPlaying = true);
        }
      } else {
        _audioPlayer?.pause();
        setState(() => _isPlaying = false);
      }
    }
  }

  Future<void> _fetchLyrics() async {
    try {
      final lyrics = await _lyricsService.getLyrics(
        widget.track.id,
        widget.track.artistName,
        widget.track.title,
        widget.track.durationSeconds,
      );
      if (mounted && lyrics != null) {
        setState(() {
          _lyrics = lyrics;
          if (lyrics.syncedLyrics != null && lyrics.syncedLyrics!.isNotEmpty) {
            _parsedLyrics = _parseSyncedLyrics(lyrics.syncedLyrics!);
          }
        });
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _parseSyncedLyrics(String lrc) {
    final lines = lrc.split('\n');
    final RegExp timeRegExp = RegExp(r'\[(\d{2}):(\d{2}\.\d{2,3})\]');
    final List<Map<String, dynamic>> parsed = [];

    for (final line in lines) {
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
    if (_isInitializing || _initialized) return;
    _isInitializing = true;

    try {
      _audioPlayer ??= AudioPlayer(handleAudioSessionActivation: false);

      String videoId = widget.track.id;
      if (videoId.startsWith('deezer_') ||
          !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId)) {
        final results = await _yt.search
            .search('${widget.track.artistName} ${widget.track.title} audio');
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

      String audioUrl = '';
      String fallbackUrl = '';

      if (manifest.muxed.isNotEmpty) {
        audioUrl = manifest.muxed.withHighestBitrate().url.toString();
        if (manifest.audioOnly.isNotEmpty) {
          fallbackUrl = manifest.audioOnly.withHighestBitrate().url.toString();
        }
      } else if (manifest.audioOnly.isNotEmpty) {
        audioUrl = manifest.audioOnly.withHighestBitrate().url.toString();
      }

      if (audioUrl.isEmpty || !mounted) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      Duration? loadedDuration;
      try {
        loadedDuration = await _audioPlayer!.setUrl(audioUrl);
      } catch (_) {
        if (fallbackUrl.isNotEmpty) {
          loadedDuration = await _audioPlayer!.setUrl(fallbackUrl);
        } else {
          rethrow;
        }
      }

      final int totalSec = (loadedDuration != null && loadedDuration.inSeconds > 0)
          ? loadedDuration.inSeconds
          : widget.track.durationSeconds;
      final int clipDur =
          widget.clipDurationSeconds > 0 ? widget.clipDurationSeconds : 20;
      if (widget.focusHighlight && totalSec > clipDur + 15) {
        int candidateStart =
            (totalSec * 0.30).round().clamp(24, totalSec - clipDur - 2);
        // Si les paroles synchronisées sont déjà chargées, aligner le départ
        // sur la ligne vocale la plus proche du moment fort (refrain)
        if (_parsedLyrics.isNotEmpty) {
          for (final item in _parsedLyrics) {
            final lineSec = ((item['time'] as int) / 1000).floor();
            if (lineSec >= 22 && lineSec <= totalSec - clipDur - 2) {
              candidateStart = lineSec;
              break;
            }
          }
        }
        _highlightStartSeconds = candidateStart;
        await _audioPlayer!.seek(Duration(seconds: _highlightStartSeconds));
      } else {
        _highlightStartSeconds = 0;
      }

      await _audioPlayer!.setVolume(widget.isMuted ? 0.0 : 1.0);
      _initialized = true;

      if (mounted) {
        setState(() => _isLoading = false);
        if (widget.isActive) {
          _audioPlayer!.play();
          setState(() => _isPlaying = true);
        }
      }

      _positionSub?.cancel();
      _positionSub = _audioPlayer!.positionStream.listen((pos) {
        if (!mounted) return;
        final ms = pos.inMilliseconds;
        final seconds = ms / 1000.0;
        final double clipLen =
            (widget.clipDurationSeconds > 0 ? widget.clipDurationSeconds : 20)
                .toDouble();
        final double elapsed =
            (seconds - _highlightStartSeconds).clamp(0.0, clipLen + 5.0);

        if (elapsed >= clipLen) {
          _audioPlayer?.seek(Duration(seconds: _highlightStartSeconds));
          if (widget.isActive && _isPlaying) {
            _audioPlayer?.play();
          }
          setState(() {
            _currentLyricsIndex = -1;
          });
          widget.onAutoScrollTriggered?.call();
        } else {
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
              setState(() => _currentLyricsIndex = newIndex);
              _scrollToActiveLine(newIndex);
            }
          }
          setState(() {
            _progress = (elapsed / clipLen).clamp(0.0, 1.0);
          });
        }
      });
    } catch (e) {
      debugPrint("Erreur audio lyrics short: $e");
      if (mounted) setState(() => _isLoading = false);
    } finally {
      _isInitializing = false;
    }
  }

  void _scrollToActiveLine(int index) {
    if (!_lyricsScrollController.hasClients || index < 0) return;
    final target = index * 60.0;
    _lyricsScrollController.animateTo(
      target.clamp(0.0, _lyricsScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _audioPlayer?.dispose();
    _yt.close();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_audioPlayer == null) return;
    if (_isPlaying) {
      _audioPlayer!.pause();
    } else {
      context.read<PlayerCubit>().pause();
      _audioPlayer!.play();
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
      child: Stack(
        children: [
          // 1. Fond immersif atmosphérique signature issu de la pochette
          Positioned.fill(
            child: ImmersiveAtmosphereBackground(
              coverUrl: widget.track.coverUrl,
              palette: _palette,
            ),
          ),

          // 2. En-tête flottant avec miniature et titre du morceau
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: 20,
            right: 20,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141215).withValues(alpha: 0.60),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SonoritizArtwork(
                            imageUrl: widget.track.coverUrl,
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.track.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              ArtistNameDisplay(
                                artistName: widget.track.artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Vue Karaoké dynamique plein écran inspirée de LyricsScreen
          Positioned.fill(
            top: MediaQuery.of(context).padding.top + 120,
            bottom: 120,
            left: 20,
            right: 20,
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: accent))
                : _buildLyricsView(accent),
          ),

          // 4. Rail d'actions latérales dépolies
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
                      tooltip: "Aimer ce son",
                    ),
                    const SizedBox(height: 14),
                    _buildGlassActionBtn(
                      icon: Icons.open_in_full_rounded,
                      iconColor: Colors.white,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _audioPlayer?.pause();
                        setState(() => _isPlaying = false);
                        context.read<PlayerCubit>().playTrack(
                              widget.track,
                              source: 'Lyrics de sonorité',
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

          // 5. Dock Lecteur Signature au bas de l'écran
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
                _audioPlayer?.pause();
                setState(() => _isPlaying = false);
                context.read<PlayerCubit>().playTrack(
                      widget.track,
                      source: 'Lyrics de sonorité',
                    );
                context.push('/fullscreen');
              },
              progressColor: accent,
            ),
          ),

          // 6. Animation du Super Coeur sur double-tap
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

  Widget _buildLyricsView(Color accent) {
    if (_parsedLyrics.isEmpty) {
      if (_lyrics?.plainLyrics != null && _lyrics!.plainLyrics!.isNotEmpty) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30),
            child: Text(
              _lyrics!.plainLyrics!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.90),
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_outlined,
                size: 50, color: Colors.white.withValues(alpha: 0.35)),
            const SizedBox(height: 14),
            Text(
              "Paroles non disponibles pour ce titre",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _lyricsScrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 80),
      itemCount: _parsedLyrics.length,
      itemBuilder: (context, index) {
        final isCurrent = index == _currentLyricsIndex;
        final isPast = index < _currentLyricsIndex;
        final line = _parsedLyrics[index];

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            _audioPlayer?.seek(Duration(milliseconds: line['time']));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isCurrent
                  ? accent.withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: Text(
              line['text'],
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isCurrent
                    ? Colors.white
                    : (isPast
                        ? Colors.white.withValues(alpha: 0.42)
                        : Colors.white.withValues(alpha: 0.25)),
                fontSize: isCurrent ? 25 : 18.5,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                height: 1.35,
                shadows: isCurrent
                    ? [
                        Shadow(
                          color: accent.withValues(alpha: 0.55),
                          blurRadius: 16,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
