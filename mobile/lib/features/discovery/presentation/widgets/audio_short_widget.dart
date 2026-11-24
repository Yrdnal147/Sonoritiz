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
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../../features/library/presentation/cubit/library_cubit.dart';
import '../../../../features/library/presentation/cubit/library_state.dart';
import '../../../../features/player/data/models/track_model.dart';
import '../../../../features/player/presentation/cubit/player_cubit.dart';
import '../../../../features/player/presentation/widgets/player_components/immersive_player_widgets.dart';
import 'short_mini_player_widget.dart';

class AudioShortWidget extends StatefulWidget {
  final TrackModel track;
  final bool isMuted;
  final bool isActive;
  final VoidCallback? onAutoScrollTriggered;
  final int clipDurationSeconds;
  final bool focusHighlight;

  const AudioShortWidget({
    Key? key,
    required this.track,
    required this.isMuted,
    required this.isActive,
    this.onAutoScrollTriggered,
    this.clipDurationSeconds = 20,
    this.focusHighlight = false,
  }) : super(key: key);

  @override
  State<AudioShortWidget> createState() => _AudioShortWidgetState();
}

class _AudioShortWidgetState extends State<AudioShortWidget>
    with SingleTickerProviderStateMixin {
  AudioPlayer? _audioPlayer;
  final YoutubeExplode _yt = YoutubeExplode();

  bool _initialized = false;
  bool _isInitializing = false;
  bool _isPlaying = false;
  bool _isLoading = true;
  double _progress = 0.0;
  bool _showHeart = false;
  int _highlightStartSeconds = 0;

  StreamSubscription? _positionSub;
  ImmersivePalette _palette = ImmersivePalette.fallback;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadPalette();
    if (widget.isActive) {
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
  void didUpdateWidget(covariant AudioShortWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMuted != oldWidget.isMuted) {
      _audioPlayer?.setVolume(widget.isMuted ? 0.0 : 1.0);
    }
    if (widget.track.coverUrl != oldWidget.track.coverUrl) {
      _loadPalette();
    }
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
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
        _highlightStartSeconds =
            (totalSec * 0.30).round().clamp(24, totalSec - clipDur - 2);
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
        final seconds = pos.inMilliseconds / 1000.0;
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
          widget.onAutoScrollTriggered?.call();
        } else {
          setState(() {
            _progress = (elapsed / clipLen).clamp(0.0, 1.0);
          });
        }
      });
    } catch (e) {
      debugPrint("Erreur audio short: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } finally {
      _isInitializing = false;
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _audioPlayer?.dispose();
    _yt.close();
    _pulseController.dispose();
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

          // 2. Zone centrale : Pochette signature en lévitation avec halo thermique
          Align(
            alignment: const Alignment(0, -0.22),
            child: _isLoading
                ? CircularProgressIndicator(color: accent)
                : ScaleTransition(
                    scale: _isPlaying
                        ? _pulseAnimation
                        : const AlwaysStoppedAnimation(1.0),
                    child: Container(
                      width: 290,
                      height: 290,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.38),
                            blurRadius: 48,
                            spreadRadius: 4,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(27),
                        child: SonoritizArtwork(
                          imageUrl: widget.track.coverUrl,
                          width: 290,
                          height: 290,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
          ),

          // 3. Vibration acoustique signature au centre (barres fines animées)
          Positioned(
            left: 36,
            right: 36,
            bottom: 124,
            child: _buildSignatureAcousticScale(accent),
          ),

          // 4. Rail d'actions verticales à droite en verre dépoli néo-noir
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
                              source: 'Sonorités en audios',
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
                      source: 'Sonorités en audios',
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

  /// Bouton flottant circulaire en verre dépoli
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

  /// Rangée de vibration signature reproduisant l'onde acoustique Sonoritiz
  Widget _buildSignatureAcousticScale(Color accent) {
    return Opacity(
      opacity: _isPlaying ? 0.9 : 0.35,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(24, (index) {
          final double factor =
              ((index * 7 + (_progress * 24).toInt()) % 12 + 4).toDouble();
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 3.5,
            height: _isPlaying ? factor * 1.8 : 4.0,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  accent.withValues(alpha: 0.9),
                  accent.withValues(alpha: 0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}
