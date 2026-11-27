import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/palette_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/share_utils.dart';
import '../../../../core/widgets/artist_name_display.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../data/models/lyrics_model.dart';
import '../../data/models/track_model.dart';
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
  final LyricsService _lyricsService = LyricsService();
  Future<LyricsModel?>? _lyricsFuture;
  String? _currentTrackId;
  String? _lastCoverUrl;
  ImmersivePalette _palette = ImmersivePalette.fallback;
  int _syncOffsetMilliseconds = 0;

  // Mode sélection de 1 à 4 lignes pour générer la Carte Visuelle « Sonoritiz Lyric Card »
  bool _isSelectingForShare = false;
  final Set<int> _selectedShareLineIndices = <int>{};
  bool _isGeneratingShareCard = false;

  Future<void> _updatePaletteForCover(String coverUrl) async {
    final trimmed = coverUrl.trim();
    if (trimmed.isEmpty || _lastCoverUrl == trimmed) return;
    _lastCoverUrl = trimmed;

    final cached = PaletteService.getCached(trimmed);
    if (cached != null) {
      if (mounted) {
        setState(() => _palette = cached);
      }
      return;
    }

    try {
      final extracted = await PaletteService.getPalette(trimmed);
      if (mounted && _lastCoverUrl == trimmed) {
        setState(() => _palette = extracted);
      }
    } catch (_) {}
  }

  void _toggleShareSelectionMode({
    int? initialIndex,
    List<LrcLine>? syncedLines,
    Duration? currentPosition,
  }) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectingForShare = !_isSelectingForShare;
      _selectedShareLineIndices.clear();
      if (_isSelectingForShare) {
        if (initialIndex != null) {
          _selectedShareLineIndices.add(initialIndex);
        } else if (syncedLines != null &&
            syncedLines.isNotEmpty &&
            currentPosition != null) {
          int activeIdx = 0;
          final posMs =
              currentPosition.inMilliseconds + _syncOffsetMilliseconds;
          for (int i = 0; i < syncedLines.length; i++) {
            if (posMs >= syncedLines[i].time.inMilliseconds) {
              activeIdx = i;
            } else {
              break;
            }
          }
          _selectedShareLineIndices.add(activeIdx);
          if (activeIdx + 1 < syncedLines.length &&
              syncedLines[activeIdx + 1].text.trim().isNotEmpty) {
            _selectedShareLineIndices.add(activeIdx + 1);
          }
        }
      }
    });
  }

  void _onToggleLineForShare(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedShareLineIndices.contains(index)) {
        _selectedShareLineIndices.remove(index);
      } else {
        if (_selectedShareLineIndices.length >= 4) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF181820),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
              content: Text(
                'Tu peux sélectionner jusqu’à 4 lignes par carte.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
          return;
        }
        _selectedShareLineIndices.add(index);
      }
    });
  }

  Future<void> _shareSelectedLyrics({
    required TrackModel track,
    required List<String> linesToShare,
  }) async {
    if (_isGeneratingShareCard || linesToShare.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _isGeneratingShareCard = true);
    try {
      await ShareUtils.shareLyricsCard(
        track: track,
        lyricLines: linesToShare,
        dominantColor: _palette.dominantColor,
        deepColor: _palette.deepColor,
        accentColor: _palette.accentColor,
      );
      if (mounted) {
        setState(() {
          _isSelectingForShare = false;
          _selectedShareLineIndices.clear();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingShareCard = false);
      }
    }
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

          if (_currentTrackId != track.id) {
            _currentTrackId = track.id;
            _isSelectingForShare = false;
            _selectedShareLineIndices.clear();
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
              // 1. Fond immersif à la couleur dominante de la pochette
              Positioned.fill(
                child: ImmersiveAtmosphereBackground(
                  coverUrl: track.coverUrl,
                  palette: _palette,
                ),
              ),
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.26),
                ),
              ),

              // 2. Espace supérieur & central 100 % dédié à : Pochette + Titre/Artiste + Paroles
              SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: effectiveTopPadding + 10),

                    // En-tête épuré pleine largeur : Retour ⌄ + Grande Pochette + Titre + Artiste
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 20, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
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
                          const SizedBox(width: 14),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: _palette.dominantColor
                                      .withValues(alpha: 0.42),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: SonoritizArtwork(
                              imageUrl: track.coverUrl,
                              width: 56,
                              height: 56,
                              borderRadius: 15,
                              cacheMaxDimension: 220,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  track.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18.0,
                                    letterSpacing: -0.3,
                                    height: 1.18,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                ArtistNameDisplay(
                                  artistName: track.artistName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bandeau d'instruction discret uniquement lorsqu'on sélectionne des paroles à partager
                    if (_isSelectingForShare)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _palette.accentColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  _palette.accentColor.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                                color: _palette.accentColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Touche 1 à 4 lignes pour créer ta Carte Paroles (${_selectedShareLineIndices.length}/4)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() {
                                  _isSelectingForShare = false;
                                  _selectedShareLineIndices.clear();
                                }),
                                child: const Text(
                                  'Annuler',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Zone Paroles plein espace
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

                          final List<LrcLine>? syncedLines =
                              lyricsModel.hasSynced
                                  ? lyricsModel.parsedSyncedLyrics
                                  : null;

                          return Stack(
                            children: [
                              if (syncedLines != null && syncedLines.isNotEmpty)
                                BlocSelector<PlayerCubit, PlayerState,
                                    Duration>(
                                  selector: (s) => s.position,
                                  builder: (context, livePosition) {
                                    return SyncedLyricsWidget(
                                      lines: syncedLines,
                                      currentPosition: livePosition,
                                      syncOffsetMilliseconds:
                                          _syncOffsetMilliseconds,
                                      accentColor: _palette.accentColor,
                                      isSelectingForShare: _isSelectingForShare,
                                      selectedShareIndices:
                                          _selectedShareLineIndices,
                                      onToggleShareLine: _onToggleLineForShare,
                                      onLongPressLine: (idx) {
                                        if (!_isSelectingForShare) {
                                          _toggleShareSelectionMode(
                                            initialIndex: idx,
                                          );
                                        } else {
                                          _onToggleLineForShare(idx);
                                        }
                                      },
                                    );
                                  },
                                )
                              else
                                ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    28,
                                    18,
                                    28,
                                    120,
                                  ),
                                  physics: const BouncingScrollPhysics(),
                                  children: [
                                    Text(
                                      lyricsModel.plainLyrics!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.92),
                                        fontSize: 21,
                                        fontWeight: FontWeight.w700,
                                        height: 1.65,
                                      ),
                                    ),
                                  ],
                                ),

                              // 3. Dock Flottant Paroles en bas (ou barre de validation de partage)
                              Positioned(
                                left: 14,
                                right: 14,
                                bottom: 10,
                                child: _isSelectingForShare
                                    ? _buildShareConfirmDock(
                                        context,
                                        track: track,
                                        syncedLines: syncedLines,
                                        plainLyrics: lyricsModel.plainLyrics,
                                      )
                                    : _buildBottomLyricsToolsDock(
                                        context,
                                        track: track,
                                        state: state,
                                        syncedLines: syncedLines,
                                        plainLyrics: lyricsModel.plainLyrics,
                                      ),
                              ),
                            ],
                          );
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

  Widget _buildShareConfirmDock(
    BuildContext context, {
    required TrackModel track,
    required List<LrcLine>? syncedLines,
    required String? plainLyrics,
  }) {
    final List<String> selectedTexts = [];
    if (syncedLines != null && syncedLines.isNotEmpty) {
      final sorted = _selectedShareLineIndices.toList()..sort();
      for (final idx in sorted) {
        if (idx >= 0 && idx < syncedLines.length) {
          final text = syncedLines[idx].text.trim();
          if (text.isNotEmpty) selectedTexts.add(text);
        }
      }
    } else if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
      selectedTexts.addAll(
        plainLyrics
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .take(3),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121218).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _palette.accentColor.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              'assets/images/logo_transparent.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              selectedTexts.isEmpty
                  ? 'Sélectionne au moins 1 ligne'
                  : '${selectedTexts.length} ${selectedTexts.length > 1 ? "lignes prêtes" : "ligne prête"} avec logo Sonoritiz',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: selectedTexts.isEmpty || _isGeneratingShareCard
                ? null
                : () => _shareSelectedLyrics(
                      track: track,
                      linesToShare: selectedTexts,
                    ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selectedTexts.isEmpty
                    ? Colors.white24
                    : _palette.accentColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isGeneratingShareCard
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.ios_share_rounded,
                          color: Colors.black,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Partager la carte',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomLyricsToolsDock(
    BuildContext context, {
    required TrackModel track,
    required PlayerState state,
    required List<LrcLine>? syncedLines,
    required String? plainLyrics,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111117).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Contrôle direct [ - Sync 0.0s + ] conservé en 1 clic dans le dock inférieur
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _syncOffsetMilliseconds == 0
                    ? Colors.white.withValues(alpha: 0.12)
                    : _palette.accentColor.withValues(alpha: 0.55),
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
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                    child: Icon(
                      Icons.remove_rounded,
                      size: 15,
                      color: Colors.white70,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _syncOffsetMilliseconds == 0
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() => _syncOffsetMilliseconds = 0);
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      _syncOffsetMilliseconds == 0
                          ? 'Sync 0.0s'
                          : 'Sync ${_syncOffsetMilliseconds > 0 ? '+' : ''}${(_syncOffsetMilliseconds / 1000.0).toStringAsFixed(1)}s',
                      style: TextStyle(
                        color: _syncOffsetMilliseconds == 0
                            ? Colors.white.withValues(alpha: 0.88)
                            : _palette.accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _syncOffsetMilliseconds += 500);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                    child: Icon(
                      Icons.add_rounded,
                      size: 15,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Atténuation vocale / Instrumental
          VocalRemoverCompactButton(
            accentColor: _palette.accentColor,
          ),

          // 3. Mode Karaoké (icône Microphone de scène, remplace les confettis et le doublon Party XXL)
          ImmersiveGlassCircleButton(
            tooltip: 'Mode Karaoké',
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
              Icons.mic_external_on_rounded,
              size: 19,
              color: Colors.white,
            ),
          ),

          // 4. Partager en Carte Paroles (« Sonoritiz Lyric Card » avec logo transparent)
          ImmersiveGlassCircleButton(
            tooltip: 'Partager des paroles en carte',
            onTap: () {
              if (syncedLines != null && syncedLines.isNotEmpty) {
                _toggleShareSelectionMode(
                  syncedLines: syncedLines,
                  currentPosition: context.read<PlayerCubit>().state.position,
                );
              } else if (plainLyrics != null &&
                  plainLyrics.trim().isNotEmpty) {
                final excerpt = plainLyrics
                    .split('\n')
                    .map((l) => l.trim())
                    .where((l) => l.isNotEmpty)
                    .take(3)
                    .toList();
                _shareSelectedLyrics(track: track, linesToShare: excerpt);
              }
            },
            child: const Icon(
              Icons.ios_share_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),

          // 5. Sous-titres / Paroles sur le lecteur
          ImmersiveGlassCircleButton(
            tooltip: state.isFreeLyricsMode
                ? 'Paroles sur lecteur : Activé'
                : 'Paroles sur lecteur : Désactivé',
            isHighlighted: state.isFreeLyricsMode,
            onTap: () {
              HapticFeedback.selectionClick();
              context.read<PlayerCubit>().toggleFreeLyricsMode();
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
    );
  }
}

class SyncedLyricsWidget extends StatefulWidget {
  final List<LrcLine> lines;
  final Duration currentPosition;
  final int syncOffsetMilliseconds;
  final Color accentColor;
  final bool isSelectingForShare;
  final Set<int> selectedShareIndices;
  final ValueChanged<int>? onToggleShareLine;
  final ValueChanged<int>? onLongPressLine;

  const SyncedLyricsWidget({
    super.key,
    required this.lines,
    required this.currentPosition,
    this.syncOffsetMilliseconds = 0,
    this.accentColor = AppColors.primary,
    this.isSelectingForShare = false,
    this.selectedShareIndices = const <int>{},
    this.onToggleShareLine,
    this.onLongPressLine,
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
    if (widget.isSelectingForShare ||
        _isManualScrolling ||
        !_scrollController.hasClients) {
      return;
    }

    final double targetOffset = (index * 68.0) - 45.0;
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
          top: 18.0,
          bottom: MediaQuery.of(context).size.height * 0.36,
          left: 18.0,
          right: 18.0,
        ),
        physics: const BouncingScrollPhysics(),
        itemCount: widget.lines.length,
        itemBuilder: (context, index) {
          final line = widget.lines[index];
          final bool isActive = index == activeIndex;
          final bool isPast = activeIndex != -1 && index < activeIndex;
          final bool isSelectedForShare =
              widget.isSelectingForShare &&
              widget.selectedShareIndices.contains(index);

          return GestureDetector(
            onTap: () {
              if (widget.isSelectingForShare) {
                widget.onToggleShareLine?.call(index);
                return;
              }
              HapticFeedback.selectionClick();
              context.read<PlayerCubit>().seek(line.time);
              _isManualScrolling = false;
              _resumeScrollTimer?.cancel();
            },
            onLongPress: () => widget.onLongPressLine?.call(index),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              padding: EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: (isActive || isSelectedForShare) ? 12.0 : 8.0,
              ),
              decoration: BoxDecoration(
                color: isSelectedForShare
                    ? widget.accentColor.withValues(alpha: 0.26)
                    : (isActive
                        ? widget.accentColor.withValues(alpha: 0.16)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(18),
                border: (isActive || isSelectedForShare)
                    ? Border.all(
                        color: widget.accentColor.withValues(
                          alpha: isSelectedForShare ? 0.85 : 0.36,
                        ),
                        width: isSelectedForShare ? 1.4 : 1.0,
                      )
                    : null,
              ),
              child: Row(
                children: [
                  if (widget.isSelectingForShare) ...[
                    Icon(
                      isSelectedForShare
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 19,
                      color: isSelectedForShare
                          ? widget.accentColor
                          : Colors.white38,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        color: (isActive || isSelectedForShare)
                            ? Colors.white
                            : Colors.white
                                .withValues(alpha: isPast ? 0.32 : 0.50),
                        fontSize: isActive ? 24.0 : 19.0,
                        fontWeight: (isActive || isSelectedForShare)
                            ? FontWeight.w800
                            : FontWeight.w600,
                        height: 1.32,
                        shadows: isActive
                            ? [
                                Shadow(
                                  color: widget.accentColor
                                      .withValues(alpha: 0.55),
                                  blurRadius: 16,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        line.text.isEmpty ? '♪' : line.text,
                        textAlign: widget.isSelectingForShare
                            ? TextAlign.left
                            : TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
