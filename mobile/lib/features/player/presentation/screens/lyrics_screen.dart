import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../data/models/lyrics_model.dart';
import '../../data/services/lyrics_service.dart';
import '../cubit/player_cubit.dart';
import '../cubit/player_state.dart';
import '../widgets/player_components/immersive_player_widgets.dart';
import '../widgets/vocal_remover_slider.dart';
import 'karaoke_party_screen.dart';

class LyricsScreen extends StatefulWidget {
  const LyricsScreen({super.key});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  static final Map<String, ImmersivePalette> _paletteCache =
      <String, ImmersivePalette>{};

  final LyricsService _lyricsService = LyricsService();
  Future<LyricsModel?>? _lyricsFuture;
  String? _currentTrackId;
  String? _lastCoverUrl;
  ImmersivePalette _palette = ImmersivePalette.fallback;
  int _syncOffsetMilliseconds = 0;

  Future<void> _updatePaletteForCover(String coverUrl) async {
    final trimmed = coverUrl.trim();
    if (trimmed.isEmpty || _lastCoverUrl == trimmed) return;
    _lastCoverUrl = trimmed;

    final cached = _paletteCache[trimmed];
    if (cached != null) {
      if (mounted) {
        setState(() => _palette = cached);
      }
      return;
    }

    try {
      ImageProvider baseProvider;
      if (trimmed.startsWith('file://')) {
        final file = File(trimmed.replaceFirst('file://', ''));
        if (!file.existsSync()) return;
        baseProvider = FileImage(file);
      } else if (trimmed.startsWith('http://') ||
          trimmed.startsWith('https://')) {
        baseProvider = CachedNetworkImageProvider(trimmed);
      } else {
        return;
      }

      final resized = ResizeImage(baseProvider, width: 48, height: 48);
      final gen = await PaletteGenerator.fromImageProvider(
        resized,
        maximumColorCount: 8,
      );
      final extracted = ImmersivePalette.fromExtracted(
        dominant: gen.dominantColor?.color,
        vibrant: gen.vibrantColor?.color,
        muted: gen.mutedColor?.color,
        darkMuted: gen.darkMutedColor?.color,
      );
      if (_paletteCache.length >= 40) {
        _paletteCache.remove(_paletteCache.keys.first);
      }
      _paletteCache[trimmed] = extracted;
      if (mounted && _lastCoverUrl == trimmed) {
        setState(() => _palette = extracted);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _palette.deepColor,
      body: BlocBuilder<PlayerCubit, PlayerState>(
        buildWhen: (prev, cur) =>
            prev.currentTrack != cur.currentTrack ||
            prev.currentLyrics != cur.currentLyrics ||
            prev.isFreeLyricsMode != cur.isFreeLyricsMode ||
            prev.isPlaying != cur.isPlaying,
        builder: (context, state) {
          final track = state.currentTrack;
          if (track == null) {
            return const Center(
              child: Text(
                'Aucun morceau en cours',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          if (_lastCoverUrl != track.coverUrl) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _updatePaletteForCover(track.coverUrl);
            });
          }

          // Réutiliser state.currentLyrics s'il est déjà chargé, sinon lancer la requête une seule fois par piste
          if (_currentTrackId != track.id) {
            _currentTrackId = track.id;
            if (state.currentLyrics != null &&
                (state.currentLyrics!.hasSynced ||
                    state.currentLyrics!.hasPlain)) {
              _lyricsFuture = Future.value(state.currentLyrics);
            } else {
              _lyricsFuture = _lyricsService.getLyrics(
                track.id,
                track.artistName,
                track.title,
                track.durationSeconds,
              );
            }
          }

          final view = View.of(context);
          final viewMediaQuery = MediaQueryData.fromView(view);
          double effectiveTopPadding = 38.0;
          for (final v in [
            MediaQuery.of(context).padding.top,
            MediaQuery.of(context).viewPadding.top,
            viewMediaQuery.padding.top,
            viewMediaQuery.viewPadding.top,
          ]) {
            if (v > effectiveTopPadding) effectiveTopPadding = v;
          }

          return Stack(
            children: [
              // 1. Fond immersif à la couleur de la pochette (isolé par RepaintBoundary, 120px en VRAM)
              Positioned.fill(
                child: ImmersiveAtmosphereBackground(
                  coverUrl: track.coverUrl,
                  palette: _palette,
                ),
              ),
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.28),
                ),
              ),

              // 2. Contenu principal
              SafeArea(
                top: false,
                child: Column(
                  children: [
                    SizedBox(height: effectiveTopPadding + 8),

                    // En-tête « Signature Sonoritiz » avec mini-pochette + titre/artiste + toggle paroles libres
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 6.0,
                      ),
                      child: Row(
                        children: [
                          ImmersiveGlassCircleButton(
                            tooltip: 'Fermer',
                            onTap: () => Navigator.pop(context),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              padding: const EdgeInsets.fromLTRB(7, 6, 12, 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.34),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  width: 0.9,
                                ),
                              ),
                              child: Row(
                                children: [
                                  SonoritizArtwork(
                                    imageUrl: track.coverUrl,
                                    width: 34,
                                    height: 34,
                                    borderRadius: 10,
                                    cacheMaxDimension: 120,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          track.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14.0,
                                            height: 1.15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          track.artistName,
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.72),
                                            fontSize: 12.0,
                                            fontWeight: FontWeight.w600,
                                            height: 1.15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          VocalRemoverCompactButton(
                            accentColor: _palette.accentColor,
                          ),
                          const SizedBox(width: 8),
                          ImmersiveGlassCircleButton(
                            tooltip: 'Lancer le Mode Party / Karaoké',
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<PlayerCubit>(),
                                    child: const KaraokePartyScreen(),
                                  ),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.celebration_rounded,
                              size: 19,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ImmersiveGlassCircleButton(
                            tooltip: state.isFreeLyricsMode
                                ? 'Paroles sur lecteur : Activé'
                                : 'Paroles sur lecteur : Désactivé',
                            isHighlighted: state.isFreeLyricsMode,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              context
                                  .read<PlayerCubit>()
                                  .toggleFreeLyricsMode();
                            },
                            child: Icon(
                              state.isFreeLyricsMode
                                  ? Icons.subtitles_rounded
                                  : Icons.subtitles_off_outlined,
                              size: 19,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Vue des paroles (Dynamique)
                    Expanded(
                      child: FutureBuilder<LyricsModel?>(
                        future: _lyricsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: _palette.accentColor,
                              ),
                            );
                          }

                          final lyricsModel = snapshot.data ??
                              ((state.currentLyrics != null &&
                                      (state.currentLyrics!.hasSynced ||
                                          state.currentLyrics!.hasPlain))
                                  ? state.currentLyrics
                                  : null);

                          if (lyricsModel == null ||
                              (!lyricsModel.hasSynced &&
                                  !lyricsModel.hasPlain)) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32.0,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lyrics_outlined,
                                      size: 56,
                                      color:
                                          Colors.white.withValues(alpha: 0.35),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Paroles indisponibles pour ce titre.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.75),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          if (lyricsModel.hasSynced) {
                            return Column(
                              children: [
                                // Contrôle de synchronisation en pilule de verre + Raccourci Mode Party XXL
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.black.withValues(alpha: 0.32),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.14),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                setState(() {
                                                  _syncOffsetMilliseconds -= 500;
                                                });
                                              },
                                              behavior: HitTestBehavior.opaque,
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                child: Icon(
                                                  Icons.remove_rounded,
                                                  size: 16,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                              ),
                                              child: Text(
                                                _syncOffsetMilliseconds == 0
                                                    ? 'Sync 0.0s'
                                                    : 'Sync ${_syncOffsetMilliseconds > 0 ? '+' : ''}${(_syncOffsetMilliseconds / 1000.0).toStringAsFixed(1)}s',
                                                style: TextStyle(
                                                  color: _syncOffsetMilliseconds == 0
                                                      ? Colors.white
                                                          .withValues(alpha: 0.85)
                                                      : _palette.accentColor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12.0,
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                setState(() {
                                                  _syncOffsetMilliseconds += 500;
                                                });
                                              },
                                              behavior: HitTestBehavior.opaque,
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                child: Icon(
                                                  Icons.add_rounded,
                                                  size: 16,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.mediumImpact();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => BlocProvider.value(
                                                value: context.read<PlayerCubit>(),
                                                child: const KaraokePartyScreen(),
                                              ),
                                            ),
                                          );
                                        },
                                        behavior: HitTestBehavior.opaque,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _palette.accentColor
                                                .withValues(alpha: 0.22),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: _palette.accentColor
                                                  .withValues(alpha: 0.55),
                                              width: 0.9,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.celebration_rounded,
                                                size: 13,
                                                color: _palette.accentColor,
                                              ),
                                              const SizedBox(width: 5),
                                              const Text(
                                                'Mode Party XXL',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11.0,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: BlocSelector<PlayerCubit, PlayerState,
                                      Duration>(
                                    selector: (s) => s.position,
                                    builder: (context, livePosition) {
                                      return SyncedLyricsWidget(
                                        lines: lyricsModel.parsedSyncedLyrics!,
                                        currentPosition: livePosition,
                                        syncOffsetMilliseconds:
                                            _syncOffsetMilliseconds,
                                        accentColor: _palette.accentColor,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return ListView(
                              padding: const EdgeInsets.all(32.0),
                              physics: const BouncingScrollPhysics(),
                              children: [
                                Text(
                                  lyricsModel.plainLyrics!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    height: 1.65,
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SyncedLyricsWidget extends StatefulWidget {
  final List<LrcLine> lines;
  final Duration currentPosition;
  final int syncOffsetMilliseconds;
  final Color accentColor;

  const SyncedLyricsWidget({
    super.key,
    required this.lines,
    required this.currentPosition,
    this.syncOffsetMilliseconds = 0,
    this.accentColor = AppColors.primary,
  });

  @override
  State<SyncedLyricsWidget> createState() => _SyncedLyricsWidgetState();
}

class _SyncedLyricsWidgetState extends State<SyncedLyricsWidget> {
  final ScrollController _scrollController = ScrollController();
  int _lastScrollIndex = -1;
  bool _isManualScrolling = false;
  Timer? _resumeScrollTimer;

  @override
  void dispose() {
    _resumeScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveLine(int index) {
    if (_isManualScrolling || !_scrollController.hasClients) return;

    final double targetOffset = index * 68.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    int activeIndex = -1;
    final adjustedPosition =
        widget.currentPosition.inMilliseconds + widget.syncOffsetMilliseconds;

    for (int i = 0; i < widget.lines.length; i++) {
      if (adjustedPosition >= widget.lines[i].time.inMilliseconds) {
        activeIndex = i;
      } else {
        break;
      }
    }

    if (activeIndex != _lastScrollIndex && activeIndex != -1) {
      _lastScrollIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveLine(activeIndex);
      });
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollStartNotification &&
            scrollNotification.dragDetails != null) {
          _isManualScrolling = true;
          _resumeScrollTimer?.cancel();
        } else if (scrollNotification is ScrollEndNotification) {
          _resumeScrollTimer?.cancel();
          _resumeScrollTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) {
              _isManualScrolling = false;
              if (_lastScrollIndex != -1) {
                _scrollToActiveLine(_lastScrollIndex);
              }
            }
          });
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).size.height * 0.20,
          bottom: MediaQuery.of(context).size.height * 0.42,
          left: 18.0,
          right: 18.0,
        ),
        physics: const BouncingScrollPhysics(),
        itemCount: widget.lines.length,
        itemBuilder: (context, index) {
          final line = widget.lines[index];
          final bool isActive = index == activeIndex;
          final bool isPast = activeIndex != -1 && index < activeIndex;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              context.read<PlayerCubit>().seek(line.time);
              _isManualScrolling = false;
              _resumeScrollTimer?.cancel();
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              padding: EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: isActive ? 12.0 : 8.0,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? widget.accentColor.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: isActive
                    ? Border.all(
                        color: widget.accentColor.withValues(alpha: 0.36),
                        width: 1.0,
                      )
                    : null,
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: isPast ? 0.30 : 0.48),
                  fontSize: isActive ? 24.0 : 19.0,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  height: 1.32,
                  shadows: isActive
                      ? [
                          Shadow(
                            color: widget.accentColor.withValues(alpha: 0.55),
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  line.text.isEmpty ? '♪' : line.text,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
