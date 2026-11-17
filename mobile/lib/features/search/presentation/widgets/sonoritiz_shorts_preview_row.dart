import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../../core/services/palette_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/artist_name_display.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../discovery/presentation/cubit/discovery_cubit.dart';
import '../../../discovery/presentation/cubit/discovery_state.dart';
import '../../../player/data/models/lyrics_model.dart';
import '../../../player/data/models/track_model.dart';
import '../../../player/data/services/lyrics_service.dart';
import '../../../player/presentation/widgets/player_components/immersive_player_widgets.dart';

/// Aperçus vivants des 3 formats Sonoritiz Shorts en hauteur étendue (330px).
/// Chaque carte diffuse directement un aperçu du 1er short correspondant :
/// - Clips Vidéo : lecture vidéo muette en direct (avec repli animé)
/// - Extraits Signature : immersion audio animée sur la pochette du 1er titre
/// - Karaoké Paroles : paroles synchronisées animées sur fond flouté du 1er titre
class SonoritizShortsPreviewRow extends StatelessWidget {
  const SonoritizShortsPreviewRow({super.key});

  static const double cardHeight = 330.0;
  static const double cardWidth = 208.0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiscoveryCubit, DiscoveryState>(
      builder: (context, state) {
        TrackModel? firstAudio;
        TrackModel? firstVideo;
        TrackModel? firstLyrics;
        bool isLoading = false;

        if (state is DiscoveryLoaded) {
          if (state.audioTracks.isNotEmpty) {
            firstAudio = state.audioTracks.first;
          }
          if (state.videoTracks.isNotEmpty) {
            firstVideo = state.videoTracks.first;
          }
          if (state.lyricsTracks.isNotEmpty) {
            firstLyrics = state.lyricsTracks.first;
          }
        } else if (state is DiscoveryLoading || state is DiscoveryInitial) {
          isLoading = true;
        }

        return SizedBox(
          height: cardHeight,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _VideoShortPreviewCard(
                track: firstVideo,
                isLoading: isLoading,
                onTap: () => context.push('/discovery/video'),
              ),
              const SizedBox(width: 14),
              _AudioImmersionPreviewCard(
                track: firstAudio,
                isLoading: isLoading,
                onTap: () => context.push('/discovery/audio'),
              ),
              const SizedBox(width: 14),
              _LyricsKaraokePreviewCard(
                track: firstLyrics,
                isLoading: isLoading,
                onTap: () => context.push('/discovery/lyrics'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VideoShortPreviewCard extends StatefulWidget {
  final TrackModel? track;
  final bool isLoading;
  final VoidCallback onTap;

  const _VideoShortPreviewCard({
    required this.track,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_VideoShortPreviewCard> createState() => _VideoShortPreviewCardState();
}

class _VideoShortPreviewCardState extends State<_VideoShortPreviewCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final YoutubeExplode _yt = YoutubeExplode();
  VideoPlayerController? _controller;
  late final AnimationController _kenBurnsCtrl;
  String? _loadedTrackId;
  bool _isVideoReady = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _kenBurnsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
    _maybeInitVideo();
  }

  @override
  void didUpdateWidget(covariant _VideoShortPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.track?.id != oldWidget.track?.id) {
      _maybeInitVideo();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !_isVideoReady) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (ctrl.value.isPlaying) {
        ctrl.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!ctrl.value.isPlaying) {
        ctrl.play();
      }
    }
  }

  Future<void> _maybeInitVideo() async {
    final track = widget.track;
    if (track == null || track.id == _loadedTrackId || _isDisposed) return;
    _loadedTrackId = track.id;

    final prevCtrl = _controller;
    _controller = null;
    if (mounted) {
      setState(() => _isVideoReady = false);
    }
    await prevCtrl?.dispose();

    try {
      String videoId = track.id;
      if (videoId.startsWith('deezer_') ||
          !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId)) {
        final results = await _yt.search.search(
          '${track.artistName} ${track.title} official video',
        );
        if (results.isNotEmpty) {
          videoId = results.first.id.value;
        }
      }

      if (_isDisposed || !mounted) return;

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

      if (_isDisposed || !mounted || manifest.muxed.isEmpty) return;

      // Pour un aperçu fluide et rapide, préférer un flux léger <= 480p si dispo
      final muxedSorted = manifest.muxed.sortByVideoQuality();
      final previewStream = muxedSorted.isNotEmpty ? muxedSorted.last : manifest.muxed.first;
      final videoUrl = previewStream.url.toString();
      if (videoUrl.isEmpty) return;

      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await ctrl.initialize();
      if (_isDisposed || !mounted) {
        await ctrl.dispose();
        return;
      }

      await ctrl.setVolume(0.0);
      await ctrl.setLooping(true);
      await ctrl.play();

      _controller = ctrl;
      setState(() => _isVideoReady = true);
    } catch (_) {
      // Conservation silencieuse de l'aperçu animé de la pochette
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _kenBurnsCtrl.dispose();
    _controller?.dispose();
    _yt.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;

    return _ShortPreviewCardShell(
      onTap: widget.onTap,
      background: _buildBackground(track),
      badgeText: 'Clips Vidéo',
      badgeIcon: Icons.play_arrow_rounded,
      liveLabel: _isVideoReady ? 'EN COURS' : 'VIDÉO LIVE',
      title: track?.title ?? (widget.isLoading ? 'Chargement du clip...' : 'Clips Vidéo'),
      artist: track?.artistName ?? 'Vidéos plein écran',
    );
  }

  Widget _buildBackground(TrackModel? track) {
    if (_isVideoReady &&
        _controller != null &&
        _controller!.value.isInitialized) {
      final size = _controller!.value.size;
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: size.width > 0 ? size.width : 360,
            height: size.height > 0 ? size.height : 640,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    }

    if (track != null && track.coverUrl.isNotEmpty) {
      return AnimatedBuilder(
        animation: _kenBurnsCtrl,
        builder: (context, child) {
          final scale = 1.04 + (_kenBurnsCtrl.value * 0.10);
          final dx = (_kenBurnsCtrl.value - 0.5) * 10;
          return Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          );
        },
        child: SonoritizArtwork(
          imageUrl: track.coverUrl,
          width: SonoritizShortsPreviewRow.cardWidth,
          height: SonoritizShortsPreviewRow.cardHeight,
          borderRadius: 0,
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F1629), Color(0xFF0E0E12)],
        ),
      ),
    );
  }
}

class _AudioImmersionPreviewCard extends StatefulWidget {
  final TrackModel? track;
  final bool isLoading;
  final VoidCallback onTap;

  const _AudioImmersionPreviewCard({
    required this.track,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_AudioImmersionPreviewCard> createState() =>
      _AudioImmersionPreviewCardState();
}

class _AudioImmersionPreviewCardState extends State<_AudioImmersionPreviewCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  ImmersivePalette _palette = ImmersivePalette.fallback;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _extractPalette();
  }

  @override
  void didUpdateWidget(covariant _AudioImmersionPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.track?.coverUrl != oldWidget.track?.coverUrl) {
      _extractPalette();
    }
  }

  Future<void> _extractPalette() async {
    final cover = widget.track?.coverUrl ?? '';
    if (cover.isEmpty) return;
    final palette = await PaletteService.getPalette(cover);
    if (mounted) {
      setState(() => _palette = palette);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;

    return _ShortPreviewCardShell(
      onTap: widget.onTap,
      background: _buildImmersionBackground(track),
      centerOverlay: _buildCenterArtworkAndBars(track),
      badgeText: 'Extraits Signature',
      badgeIcon: Icons.headphones_rounded,
      liveLabel: 'IMMERSION',
      title: track?.title ??
          (widget.isLoading ? 'Chargement audio...' : 'Extraits Signature'),
      artist: track?.artistName ?? 'Le son en immersion',
    );
  }

  Widget _buildImmersionBackground(TrackModel? track) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (track != null && track.coverUrl.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: SonoritizArtwork(
              imageUrl: track.coverUrl,
              width: SonoritizShortsPreviewRow.cardWidth,
              height: SonoritizShortsPreviewRow.cardHeight,
              borderRadius: 0,
            ),
          )
        else
          Container(color: const Color(0xFF171311)),
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, _) {
            final glowAlpha = 0.24 + (_pulseCtrl.value * 0.20);
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 0.95,
                  colors: [
                    _palette.dominantColor.withValues(alpha: glowAlpha),
                    _palette.deepColor.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.86),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCenterArtworkAndBars(TrackModel? track) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) {
                final scale = 0.97 + (_pulseCtrl.value * 0.055);
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _palette.accentColor.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _palette.dominantColor.withValues(alpha: 0.42),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: track != null && track.coverUrl.isNotEmpty
                      ? SonoritizArtwork(
                          imageUrl: track.coverUrl,
                          width: 108,
                          height: 108,
                          borderRadius: 54,
                        )
                      : Container(
                          width: 108,
                          height: 108,
                          color: const Color(0xFF222228),
                          child: const Icon(
                            Icons.headphones_rounded,
                            color: Colors.white54,
                            size: 38,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Mini égaliseur animé sans clic
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) {
                final t = _pulseCtrl.value * math.pi;
                const multi = [0.55, 0.95, 0.72, 1.0, 0.62, 0.88, 0.50];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(multi.length, (i) {
                    final wave =
                        (0.35 + 0.65 * ((math.sin(t * 2 + i * 0.9) + 1) / 2)) *
                            multi[i];
                    return Container(
                      width: 3.5,
                      height: 8 + (wave * 18),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i.isEven
                            ? _palette.accentColor
                            : Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LyricsKaraokePreviewCard extends StatefulWidget {
  final TrackModel? track;
  final bool isLoading;
  final VoidCallback onTap;

  const _LyricsKaraokePreviewCard({
    required this.track,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_LyricsKaraokePreviewCard> createState() =>
      _LyricsKaraokePreviewCardState();
}

class _LyricsKaraokePreviewCardState extends State<_LyricsKaraokePreviewCard> {
  final LyricsService _lyricsService = LyricsService();
  ImmersivePalette _palette = ImmersivePalette.fallback;
  List<String> _lines = const [];
  int _activeIndex = 0;
  Timer? _cycleTimer;
  String? _loadedTrackId;

  @override
  void initState() {
    super.initState();
    _loadData();
    _cycleTimer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (!mounted || _lines.isEmpty) return;
      setState(() {
        _activeIndex = (_activeIndex + 1) % _lines.length;
      });
    });
  }

  @override
  void didUpdateWidget(covariant _LyricsKaraokePreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.track?.id != oldWidget.track?.id) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final track = widget.track;
    if (track == null || track.id == _loadedTrackId) return;
    _loadedTrackId = track.id;

    // Fallback instantané tant que l'API des paroles répond
    setState(() {
      _lines = [
        track.title,
        'par ${track.artistName}',
        'Paroles synchronisées en direct...',
        'Appuyez pour chanter en plein écran',
      ];
      _activeIndex = 0;
    });

    final palette = await PaletteService.getPalette(track.coverUrl);
    if (mounted) {
      setState(() => _palette = palette);
    }

    try {
      final LyricsModel? model = await _lyricsService.getLyrics(
        track.id,
        track.artistName,
        track.title,
        track.durationSeconds,
      );
      if (!mounted || model == null) return;

      final List<String> extracted = [];
      if (model.hasSynced && model.parsedSyncedLyrics != null) {
        for (final line in model.parsedSyncedLyrics!) {
          final text = line.text.trim();
          if (text.isNotEmpty) extracted.add(text);
        }
      } else if (model.hasPlain && model.plainLyrics != null) {
        for (final raw in model.plainLyrics!.split('\n')) {
          final text = raw.trim();
          if (text.isNotEmpty) extracted.add(text);
        }
      }

      if (extracted.isNotEmpty && mounted) {
        setState(() {
          _lines = extracted.take(24).toList();
          _activeIndex = 0;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;

    return _ShortPreviewCardShell(
      onTap: widget.onTap,
      background: _buildBackground(track),
      centerOverlay: _buildScrollingLyricsPreview(),
      badgeText: 'Karaoké Paroles',
      badgeIcon: Icons.lyrics_rounded,
      liveLabel: 'KARAOKE',
      title: track?.title ??
          (widget.isLoading ? 'Chargement paroles...' : 'Karaoké Paroles'),
      artist: track?.artistName ?? 'Lyrics synchronisées',
    );
  }

  Widget _buildBackground(TrackModel? track) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (track != null && track.coverUrl.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: SonoritizArtwork(
              imageUrl: track.coverUrl,
              width: SonoritizShortsPreviewRow.cardWidth,
              height: SonoritizShortsPreviewRow.cardHeight,
              borderRadius: 0,
            ),
          )
        else
          Container(color: const Color(0xFF101923)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _palette.deepColor.withValues(alpha: 0.72),
                Colors.black.withValues(alpha: 0.78),
                Colors.black.withValues(alpha: 0.92),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScrollingLyricsPreview() {
    if (_lines.isEmpty) {
      return const SizedBox.shrink();
    }

    final int prevIdx =
        (_activeIndex - 1 + _lines.length) % _lines.length;
    final int nextIdx = (_activeIndex + 1) % _lines.length;
    final int next2Idx = (_activeIndex + 2) % _lines.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 62, 16, 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_lines.length > 1)
            Text(
              _lines[prevIdx],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.36),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            child: Text(
              _lines[_activeIndex],
              key: ValueKey('$_activeIndex-${_lines[_activeIndex]}'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.22,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_lines.length > 2)
            Text(
              _lines[nextIdx],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.48),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          if (_lines.length > 3) ...[
            const SizedBox(height: 8),
            Text(
              _lines[next2Idx],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.28),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShortPreviewCardShell extends StatelessWidget {
  final VoidCallback onTap;
  final Widget background;
  final Widget? centerOverlay;
  final String badgeText;
  final IconData badgeIcon;
  final String liveLabel;
  final String title;
  final String artist;

  const _ShortPreviewCardShell({
    required this.onTap,
    required this.background,
    this.centerOverlay,
    required this.badgeText,
    required this.badgeIcon,
    required this.liveLabel,
    required this.title,
    required this.artist,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: SonoritizShortsPreviewRow.cardWidth,
          height: SonoritizShortsPreviewRow.cardHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF141418),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              background,
              // Voile lisible haut + bas sans masquer l'aperçu au centre
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.62),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.90),
                    ],
                    stops: const [0.0, 0.28, 0.62, 1.0],
                  ),
                ),
              ),
              if (centerOverlay != null) centerOverlay!,
              // En-tête de format + pastille live
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.56),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, size: 13, color: Colors.white),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                badgeText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            liveLabel,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Pied de carte : titre + artiste du 1er short + flèche
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          ArtistNameDisplay(
                            artistName: artist,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.black,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
