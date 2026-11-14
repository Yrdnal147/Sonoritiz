import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../../core/services/screen_wake_service.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../data/models/lyrics_model.dart';
import '../../data/models/track_model.dart';
import '../../data/services/lyrics_service.dart';
import '../cubit/player_cubit.dart';
import '../cubit/player_state.dart';
import '../widgets/player_components/immersive_player_widgets.dart';
import '../widgets/vocal_remover_slider.dart';

/// Écran dédié « Party / Karaoké » de Sonoritiz
/// - Mode plein écran immersif total (barres système masquées)
/// - Bascule fluide Portrait / Mode Paysage (Soirée / Salon / TV)
/// - Typographie cinétique XXL avec mise en avant dynamique
/// - Radar d'anticipation de la phrase suivante
/// - Indicateur de transition musicale / solo instrumental
/// - Curseur tactile Vocal Remover intégré
class KaraokePartyScreen extends StatefulWidget {
  const KaraokePartyScreen({super.key});

  @override
  State<KaraokePartyScreen> createState() => _KaraokePartyScreenState();
}

class _KaraokePartyScreenState extends State<KaraokePartyScreen>
    with SingleTickerProviderStateMixin {
  static final Map<String, ImmersivePalette> _paletteCache =
      <String, ImmersivePalette>{};

  final LyricsService _lyricsService = LyricsService();
  final ScrollController _scrollController = ScrollController();

  Future<LyricsModel?>? _lyricsFuture;
  String? _currentTrackId;
  String? _lastCoverUrl;
  ImmersivePalette _palette = ImmersivePalette.fallback;

  int _syncOffsetMilliseconds = 0;
  bool _isLandscape = false;
  int _lastActiveIndex = -1;
  bool _isManualScrolling = false;
  Timer? _resumeScrollTimer;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    ScreenWakeService.setKeepScreenOn(true);
    // Masquage total des barres système pour l'immersion scène
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _resumeScrollTimer?.cancel();
    _scrollController.dispose();
    _pulseController.dispose();
    // Restauration de l'affichage système standard et orientation portrait
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _toggleOrientation() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isLandscape = !_isLandscape;
    });

    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  Future<void> _updatePaletteForCover(String coverUrl) async {
    final trimmed = coverUrl.trim();
    if (trimmed.isEmpty || _lastCoverUrl == trimmed) return;
    _lastCoverUrl = trimmed;

    final cached = _paletteCache[trimmed];
    if (cached != null) {
      if (mounted) setState(() => _palette = cached);
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
      _paletteCache[trimmed] = extracted;
      if (mounted && _lastCoverUrl == trimmed) {
        setState(() => _palette = extracted);
      }
    } catch (_) {}
  }

  void _scrollToActiveLine(int index, bool isLandscape) {
    if (_isManualScrolling || !_scrollController.hasClients) return;

    final double lineHeight = isLandscape ? 120.0 : 96.0;
    final double targetOffset = (index * lineHeight) - 40;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  String _formatDuration(Duration d) {
    final totalSec = d.inSeconds;
    final min = totalSec ~/ 60;
    final sec = (totalSec % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final bool currentIsLandscape = orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocBuilder<PlayerCubit, PlayerState>(
        buildWhen: (prev, cur) =>
            prev.currentTrack != cur.currentTrack ||
            prev.currentLyrics != cur.currentLyrics ||
            prev.isPlaying != cur.isPlaying ||
            prev.vocalAttenuationLevel != cur.vocalAttenuationLevel,
        builder: (context, state) {
          final track = state.currentTrack;
          if (track == null) {
            return const Center(
              child: Text(
                'Aucun morceau en cours',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          if (_lastCoverUrl != track.coverUrl) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _updatePaletteForCover(track.coverUrl);
            });
          }

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

          return Stack(
            children: [
              // 1. Fond dynamique atmosphérique Sonoritiz Live Stage
              Positioned.fill(
                child: ImmersiveAtmosphereBackground(
                  coverUrl: track.coverUrl,
                  palette: _palette,
                ),
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final alpha = 0.32 + (_pulseController.value * 0.08);
                    return ColoredBox(
                      color: Colors.black.withValues(alpha: alpha),
                    );
                  },
                ),
              ),

              // 2. Contenu principal (responsive portrait / paysage)
              SafeArea(
                child: currentIsLandscape
                    ? _buildLandscapeLayout(context, track, state)
                    : _buildPortraitLayout(context, track, state),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // LAYOUT MODE PAYSAGE (Party / Grand Écran)
  // ==========================================
  Widget _buildLandscapeLayout(
      BuildContext context, TrackModel track, PlayerState state) {
    return Column(
      children: [
        // En-tête supérieur compact
        _buildLandscapeHeader(track, state),

        // Corps : Rail gauche (Pochette + Slider vocal) & Zone droite (Paroles XXL)
        Expanded(
          child: Row(
            children: [
              // Rail gauche
              Container(
                width: 220,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    SonoritizArtwork(
                      imageUrl: track.coverUrl,
                      width: 110,
                      height: 110,
                      borderRadius: 18,
                      cacheMaxDimension: 300,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      track.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      track.artistName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    // Slider Vocal Remover vertical sur le rail gauche
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: VocalRemoverSlider(
                          accentColor: _palette.accentColor,
                          isVertical: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Zone de droite : Paroles XXL animées
              Expanded(
                child: _buildLyricsViewport(state, isLandscape: true),
              ),
            ],
          ),
        ),

        // Barre de transport inférieure compacte
        _buildBottomTransportBar(state),
      ],
    );
  }

  // ==========================================
  // LAYOUT MODE PORTRAIT (Standard Mobile)
  // ==========================================
  Widget _buildPortraitLayout(
      BuildContext context, TrackModel track, PlayerState state) {
    return Column(
      children: [
        // En-tête supérieur
        _buildPortraitHeader(track, state),

        // Paroles XXL
        Expanded(
          child: _buildLyricsViewport(state, isLandscape: false),
        ),

        // Barre de transport et progression
        _buildBottomTransportBar(state),
      ],
    );
  }

  // ==========================================
  // EN-TÊTE PORTRAIT
  // ==========================================
  Widget _buildPortraitHeader(TrackModel track, PlayerState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ImmersiveGlassCircleButton(
            tooltip: 'Quitter le mode Karaoké',
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close_rounded, size: 22, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _palette.accentColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PARTY',
                      style: TextStyle(
                        color: _palette.accentColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${track.title} • ${track.artistName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Bouton Vocal Remover compact
          VocalRemoverCompactButton(accentColor: _palette.accentColor),
          const SizedBox(width: 8),
          // Bascule d'orientation
          ImmersiveGlassCircleButton(
            tooltip: 'Mode Paysage (Salon / Party)',
            onTap: _toggleOrientation,
            child: const Icon(
              Icons.screen_rotation_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // EN-TÊTE PAYSAGE
  // ==========================================
  Widget _buildLandscapeHeader(TrackModel track, PlayerState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          ImmersiveGlassCircleButton(
            tooltip: 'Quitter le mode Karaoké',
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _palette.accentColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.celebration_rounded,
                    size: 14, color: _palette.accentColor),
                const SizedBox(width: 6),
                Text(
                  'SONORITIZ PARTY STAGE',
                  style: TextStyle(
                    color: _palette.accentColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Raccourci synchronisation fine
          _buildSyncPill(),
          const SizedBox(width: 12),
          // Bascule vers portrait
          ImmersiveGlassCircleButton(
            tooltip: 'Mode Portrait',
            onTap: _toggleOrientation,
            child: const Icon(
              Icons.screen_rotation_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _syncOffsetMilliseconds -= 500);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(Icons.remove, size: 14, color: Colors.white70),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              _syncOffsetMilliseconds == 0
                  ? 'Sync'
                  : '${_syncOffsetMilliseconds > 0 ? '+' : ''}${(_syncOffsetMilliseconds / 1000).toStringAsFixed(1)}s',
              style: TextStyle(
                color: _syncOffsetMilliseconds == 0
                    ? Colors.white70
                    : _palette.accentColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _syncOffsetMilliseconds += 500);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(Icons.add, size: 14, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VIEWPORT DES PAROLES XXL CINÉTIQUES
  // ==========================================
  Widget _buildLyricsViewport(PlayerState state, {required bool isLandscape}) {
    return FutureBuilder<LyricsModel?>(
      future: _lyricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: _palette.accentColor),
          );
        }

        final lyrics = snapshot.data ?? state.currentLyrics;
        if (lyrics == null || (!lyrics.hasSynced && !lyrics.hasPlain)) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mic_off_outlined,
                  size: 54,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 16),
                Text(
                  'Paroles non disponibles pour ce morceau',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        if (lyrics.hasSynced) {
          return _buildSyncedStage(lyrics.parsedSyncedLyrics!, isLandscape);
        }

        // Paroles brutes texte XXL
        return ListView(
          padding: const EdgeInsets.all(32),
          physics: const BouncingScrollPhysics(),
          children: [
            Text(
              lyrics.plainLyrics!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: isLandscape ? 32 : 26,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSyncedStage(List<LrcLine> lines, bool isLandscape) {
    return BlocSelector<PlayerCubit, PlayerState, Duration>(
      selector: (s) => s.position,
      builder: (context, livePosition) {
        final adjustedMs =
            livePosition.inMilliseconds + _syncOffsetMilliseconds;
        int activeIndex = -1;

        for (int i = 0; i < lines.length; i++) {
          if (adjustedMs >= lines[i].time.inMilliseconds) {
            activeIndex = i;
          } else {
            break;
          }
        }

        // Détection de transition ou solo instrumental (> 4.5s)
        bool isInstrumentalBreak = false;
        int remainingBreakSeconds = 0;
        if (activeIndex >= 0 && activeIndex + 1 < lines.length) {
          final currentLineTime = lines[activeIndex].time.inMilliseconds;
          final nextLineTime = lines[activeIndex + 1].time.inMilliseconds;
          final gap = nextLineTime - currentLineTime;
          if (gap > 4500 && adjustedMs > (currentLineTime + 2000)) {
            final remainingMs = nextLineTime - adjustedMs;
            if (remainingMs > 500) {
              isInstrumentalBreak = true;
              remainingBreakSeconds = (remainingMs / 1000).ceil();
            }
          }
        }

        if (activeIndex != _lastActiveIndex && activeIndex != -1) {
          _lastActiveIndex = activeIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToActiveLine(activeIndex, isLandscape);
          });
        }

        // Radar d'anticipation : ligne suivante
        final String? nextLineText = (activeIndex >= 0 &&
                activeIndex + 1 < lines.length &&
                lines[activeIndex + 1].text.trim().isNotEmpty)
            ? lines[activeIndex + 1].text
            : null;

        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (scrollNotification) {
                if (scrollNotification is ScrollStartNotification &&
                    scrollNotification.dragDetails != null) {
                  _isManualScrolling = true;
                  _resumeScrollTimer?.cancel();
                } else if (scrollNotification is ScrollEndNotification) {
                  _resumeScrollTimer?.cancel();
                  _resumeScrollTimer =
                      Timer(const Duration(seconds: 4), () {
                    if (mounted) {
                      _isManualScrolling = false;
                      if (_lastActiveIndex != -1) {
                        _scrollToActiveLine(_lastActiveIndex, isLandscape);
                      }
                    }
                  });
                }
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  top: isLandscape ? 60 : 120,
                  bottom: isLandscape ? 120 : 200,
                  left: 20,
                  right: 20,
                ),
                physics: const BouncingScrollPhysics(),
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  final line = lines[index];
                  final bool isActive = index == activeIndex;
                  final bool isPast = activeIndex != -1 && index < activeIndex;

                  final double fontSize = isActive
                      ? (isLandscape ? 38.0 : 30.0)
                      : (isLandscape ? 22.0 : 18.0);

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.read<PlayerCubit>().seek(line.time);
                      _isManualScrolling = false;
                      _resumeScrollTimer?.cancel();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      margin: EdgeInsets.symmetric(
                        vertical: isActive ? 12.0 : 6.0,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: isActive ? 16.0 : 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _palette.accentColor.withValues(alpha: 0.20)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        border: isActive
                            ? Border.all(
                                color: _palette.accentColor
                                    .withValues(alpha: 0.55),
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : Colors.white.withValues(
                                  alpha: isPast ? 0.32 : 0.58),
                          fontSize: fontSize,
                          fontWeight:
                              isActive ? FontWeight.w900 : FontWeight.w600,
                          height: 1.3,
                          letterSpacing: isActive ? 0.2 : 0.0,
                          shadows: isActive
                              ? [
                                  Shadow(
                                    color: _palette.accentColor
                                        .withValues(alpha: 0.8),
                                    blurRadius: 28,
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
            ),

            // Indicateur de solo instrumental / pause
            if (isInstrumentalBreak)
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _palette.accentColor.withValues(alpha: 0.7),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _palette.accentColor.withValues(alpha: 0.3),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.graphic_eq_rounded,
                          size: 18,
                          color: _palette.accentColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '♪ Solo instrumental (${remainingBreakSeconds}s) ♪',
                          style: TextStyle(
                            color: _palette.accentColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Radar d'anticipation de la phrase suivante (Bas du viewport)
            if (nextLineText != null && !isInstrumentalBreak)
              Positioned(
                bottom: 8,
                left: 24,
                right: 24,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Prochaine phrase :',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            nextLineText,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ==========================================
  // BARRE DE TRANSPORT INFÉRIEURE
  // ==========================================
  Widget _buildBottomTransportBar(PlayerState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.10),
            width: 0.8,
          ),
        ),
      ),
      child: BlocBuilder<PlayerCubit, PlayerState>(
        builder: (context, liveState) {
          final pos = liveState.position;
          final dur = liveState.duration;
          final maxSec = dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0;
          final curSec = pos.inSeconds.toDouble().clamp(0.0, maxSec);

          return Row(
            children: [
              // Temps actuel
              Text(
                _formatDuration(pos),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              // Barre de progression fluide
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: _palette.accentColor,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
                    thumbColor: Colors.white,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: curSec,
                    min: 0.0,
                    max: maxSec,
                    onChanged: (val) {
                      context
                          .read<PlayerCubit>()
                          .seek(Duration(seconds: val.round()));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Durée totale
              Text(
                _formatDuration(dur),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              // Bouton Recul 5s
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  final newPos = pos - const Duration(seconds: 5);
                  context.read<PlayerCubit>().seek(
                        newPos < Duration.zero ? Duration.zero : newPos,
                      );
                },
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.replay_5_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 4),
              // Bouton Play / Pause géant
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.read<PlayerCubit>().togglePlayPause();
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _palette.accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _palette.accentColor.withValues(alpha: 0.45),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Icon(
                    liveState.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Bouton Avance 5s
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  final newPos = pos + const Duration(seconds: 5);
                  context.read<PlayerCubit>().seek(newPos);
                },
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.forward_5_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
