import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart' as import_go_router;
import 'package:just_audio/just_audio.dart' show LoopMode;

import '../../../../../core/audio/audio_device_service.dart';
import '../../../../../core/utils/share_utils.dart';
import '../../../../../core/widgets/artist_name_display.dart';
import '../../../../home/data/repositories/catalog_repository.dart';
import '../../../../offline/presentation/cubit/download_cubit.dart';
import '../../../data/models/track_model.dart';
import '../../cubit/player_cubit.dart';
import 'immersive_player_widgets.dart';
import 'player_favorite_button.dart';

/// ============================================================================
/// 1. SCÈNE DE VIBRATION À LA COULEUR DE LA POCHETTE + TITRE & ARTISTE CENTRÉS
/// Reproduit fidèlement le croquis « Signature Sonoritiz » :
/// - Titre centré + Nom de l'artiste centré.
/// - Juste après le nom de l'artiste : rangée de blocs verticaux alternés
///   (grands rectangles & petits carrés : ▯ ▫ ▯ ▫ ▯ ▫ ▯) vibrant à la couleur de la pochette.
/// - Halo de pulsation chromatique sur la ligne de fusion.
/// - Animation stoppée à 0 % CPU/GPU en pause et isolée dans un [RepaintBoundary].
/// ============================================================================
class SonoritizCoverVibrationStage extends StatefulWidget {
  final TrackModel track;
  final bool isPlaying;
  final bool isSuperliked;
  final ImmersivePalette palette;

  const SonoritizCoverVibrationStage({
    super.key,
    required this.track,
    required this.isPlaying,
    required this.isSuperliked,
    required this.palette,
  });

  @override
  State<SonoritizCoverVibrationStage> createState() =>
      _SonoritizCoverVibrationStageState();
}

class _SonoritizCoverVibrationStageState
    extends State<SonoritizCoverVibrationStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
    );
    if (widget.isPlaying) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SonoritizCoverVibrationStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat();
        }
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Titre centré (ex: « Mode de vie »)
          Text(
            widget.track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23.0,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.18,
              shadows: [
                Shadow(
                  color: Color(0x80000000),
                  blurRadius: 14,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // 2. Artiste centré (ex: « Tiakola »)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: ArtistNameDisplay(
                  artistName: widget.track.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    shadows: const [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 10,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 3. Juste après le nom de l'artiste : Blocs de vibration alternés (▯ ▫ ▯ ▫ ▯ ▫ ▯) à la couleur de la pochette
          SizedBox(
            height: 44,
            width: 236,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size(236, 44),
                    painter: _AlternatingBlocksVibrationPainter(
                      phase: _pulseController.value * 2 * math.pi,
                      isPlaying: widget.isPlaying,
                      isSuperliked: widget.isSuperliked,
                      accentColor: widget.palette.accentColor,
                      midColor: widget.palette.midColor,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 6),

          // 4. Ligne/aura de fusion vibrante à la couleur de la pochette
          SizedBox(
            height: 7,
            width: 190,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final double wave = widget.isPlaying
                      ? (0.55 + 0.45 * math.sin(_pulseController.value * 2 * math.pi))
                      : 0.35;
                  final Color glowColor = widget.isSuperliked
                      ? const Color(0xFFFF6D00)
                      : widget.palette.accentColor;

                  return DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 2.8,
                        colors: [
                          glowColor.withValues(alpha: 0.52 * wave),
                          glowColor.withValues(alpha: 0.18 * wave),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlternatingBlocksVibrationPainter extends CustomPainter {
  final double phase;
  final bool isPlaying;
  final bool isSuperliked;
  final Color accentColor;
  final Color midColor;

  _AlternatingBlocksVibrationPainter({
    required this.phase,
    required this.isPlaying,
    required this.isSuperliked,
    required this.accentColor,
    required this.midColor,
  });

  // Alternance exacte du croquis : Grand bloc • Petit carré • Grand bloc • Petit carré... (9 éléments symétriques)
  static const List<bool> _isTallSlot = [
    true,
    false,
    true,
    false,
    true,
    false,
    true,
    false,
    true,
  ];

  static const List<double> _freqMultipliers = [
    1.0,
    2.0,
    1.0,
    2.0,
    1.0,
    2.0,
    1.0,
    2.0,
    1.0,
  ];

  static const List<double> _phaseOffsets = [
    0.0,
    0.9,
    1.7,
    2.6,
    0.5,
    3.1,
    1.3,
    2.1,
    0.3,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = size.height / 2;
    const int count = 9;
    const double tallWidth = 16.5;
    const double smallWidth = 9.5;
    const double gap = 9.0;

    double totalRowWidth = 0;
    for (int i = 0; i < count; i++) {
      totalRowWidth += _isTallSlot[i] ? tallWidth : smallWidth;
      if (i < count - 1) totalRowWidth += gap;
    }

    double cursorX = (size.width - totalRowWidth) / 2;
    final Color primaryTint =
        isSuperliked ? const Color(0xFFFF6D00) : accentColor;
    final Color topTint =
        isSuperliked ? const Color(0xFFFFEA00) : Colors.white;

    // Halo ambiant doux derrière la rangée (0 MaskFilter coûteux)
    final Rect ambientRect = Rect.fromCenter(
      center: Offset(size.width / 2, centerY),
      width: totalRowWidth + 24,
      height: size.height,
    );
    canvas.drawOval(
      ambientRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            primaryTint.withValues(alpha: isPlaying ? 0.26 : 0.14),
            Colors.transparent,
          ],
        ).createShader(ambientRect),
    );

    for (int i = 0; i < count; i++) {
      final bool isTall = _isTallSlot[i];
      final double w = isTall ? tallWidth : smallWidth;
      final double distanceFromCenter = (i - 4).abs() / 4.0;
      final double envelope = 1.0 - (distanceFromCenter * 0.24);

      double h;
      if (isTall) {
        final double baseTall = 23.0 * envelope;
        if (isPlaying) {
          final double rawSin = math.sin(phase * _freqMultipliers[i] + _phaseOffsets[i]);
          final double smoothWave = 0.5 + 0.5 * (rawSin * 0.85 + (rawSin * rawSin * rawSin) * 0.15);
          h = (baseTall * 0.65) + (smoothWave * 19.0 * envelope);
        } else {
          h = baseTall;
        }
      } else {
        const double baseSmall = 9.5;
        if (isPlaying) {
          final double rawCos = math.cos(phase * _freqMultipliers[i] + _phaseOffsets[i]);
          final double smoothWave = 0.5 + 0.5 * (rawCos * 0.85 + (rawCos * rawCos * rawCos) * 0.15);
          h = (baseSmall * 0.75) + (smoothWave * 7.5);
        } else {
          h = baseSmall;
        }
      }

      final Rect blockRect = Rect.fromCenter(
        center: Offset(cursorX + w / 2, centerY),
        width: w,
        height: h.clamp(7.0, size.height - 2.0),
      );
      final RRect rrect = RRect.fromRectAndRadius(
        blockRect,
        Radius.circular(isTall ? 5.5 : 4.0),
      );

      // Remplissage translucide teinté par la couleur de la pochette
      final Paint fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            midColor.withValues(alpha: 0.50),
            primaryTint.withValues(alpha: isTall ? 0.68 : 0.78),
            topTint.withValues(alpha: 0.90),
          ],
        ).createShader(blockRect);
      canvas.drawRRect(rrect, fillPaint);

      // Contour net lumineux façon croquis « Signature Sonoritiz »
      final Paint borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.35
        ..color = Color.lerp(primaryTint, Colors.white, 0.60)!
            .withValues(alpha: 0.92);
      canvas.drawRRect(rrect, borderPaint);

      // Reflet supérieur lumineux subtil sur les grands blocs
      if (isTall && h > 14) {
        final Rect capRect = Rect.fromLTWH(blockRect.left + 2, blockRect.top + 1.2, w - 4, 2.5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(capRect, const Radius.circular(2)),
          Paint()..color = Colors.white.withValues(alpha: isPlaying ? 0.45 : 0.25),
        );
      }

      cursorX += w + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _AlternatingBlocksVibrationPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.isSuperliked != isSuperliked ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.midColor != midColor;
  }
}

/// ============================================================================
/// 2. COMPTEUR CENTRÉ (00:00 • 03:20) + JAUGE HORIZONTALE CALIBRÉE (───●────)
/// ============================================================================
class SonoritizCenteredScrubber extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final bool isSuperliked;
  final ImmersivePalette palette;
  final ValueChanged<Duration> onSeek;

  const SonoritizCenteredScrubber({
    super.key,
    required this.position,
    required this.duration,
    required this.isSuperliked,
    required this.palette,
    required this.onSeek,
  });

  @override
  State<SonoritizCenteredScrubber> createState() =>
      _SonoritizCenteredScrubberState();
}

class _SonoritizCenteredScrubberState extends State<SonoritizCenteredScrubber> {
  double? _dragFraction;

  double _effectiveFraction() {
    if (_dragFraction != null) return _dragFraction!.clamp(0.0, 1.0);
    final int totalMs = widget.duration.inMilliseconds;
    if (totalMs <= 0) return 0.0;
    return (widget.position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  String _formatDuration(Duration d) {
    final totalSec = d.inSeconds.clamp(0, 359999);
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final double fraction = _effectiveFraction();
    final bool isDragging = _dragFraction != null;
    final int totalMs = widget.duration.inMilliseconds;
    final Duration displayPos = isDragging
        ? Duration(milliseconds: (fraction * totalMs).round())
        : widget.position;

    final Color accent = widget.isSuperliked
        ? const Color(0xFFFF6D00)
        : widget.palette.accentColor;

    return RepaintBoundary(
      child: Padding(
        // Marges latérales calibrées comme sur le croquis (barre centrée non collée aux bords)
        padding: const EdgeInsets.symmetric(horizontal: 42),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compteur groupé au centre : 00:00 • 03:20
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatDuration(displayPos),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: Container(
                    width: 4.5,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Text(
                  _formatDuration(widget.duration),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 2),

            // Jauge horizontale avec curseur rond
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    if (width <= 0) return;
                    HapticFeedback.selectionClick();
                    final f = (details.localPosition.dx / width).clamp(0.0, 1.0);
                    widget.onSeek(
                      Duration(milliseconds: (f * totalMs).round()),
                    );
                  },
                  onHorizontalDragStart: (details) {
                    if (width <= 0) return;
                    HapticFeedback.selectionClick();
                    setState(() {
                      _dragFraction =
                          (details.localPosition.dx / width).clamp(0.0, 1.0);
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    if (width <= 0) return;
                    setState(() {
                      _dragFraction =
                          (details.localPosition.dx / width).clamp(0.0, 1.0);
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    if (_dragFraction != null) {
                      final targetMs = (_dragFraction! * totalMs).round();
                      widget.onSeek(Duration(milliseconds: targetMs));
                      setState(() => _dragFraction = null);
                    }
                  },
                  onHorizontalDragCancel: () {
                    if (_dragFraction != null) {
                      setState(() => _dragFraction = null);
                    }
                  },
                  child: SizedBox(
                    height: 28,
                    width: width,
                    child: CustomPaint(
                      size: Size(width, 28),
                      painter: _CenteredLinearGaugePainter(
                        fraction: fraction,
                        isDragging: isDragging,
                        accentColor: accent,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredLinearGaugePainter extends CustomPainter {
  final double fraction;
  final bool isDragging;
  final Color accentColor;

  _CenteredLinearGaugePainter({
    required this.fraction,
    required this.isDragging,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cy = size.height / 2;
    final double thumbRadius = isDragging ? 7.5 : 5.8;
    final double usableWidth = math.max(0.0, size.width - thumbRadius * 2);
    final double startX = thumbRadius;
    final double endX = size.width - thumbRadius;
    final double thumbX = startX + usableWidth * fraction.clamp(0.0, 1.0);

    // Piste inactive
    final Paint inactivePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(startX, cy), Offset(endX, cy), inactivePaint);

    // Piste active teintée par la couleur de la pochette
    if (thumbX > startX) {
      final Rect activeRect = Rect.fromLTRB(startX, cy - 3, thumbX, cy + 3);
      final Paint activePaint = Paint()
        ..strokeWidth = isDragging ? 4.4 : 3.6
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            Colors.white,
            accentColor,
          ],
        ).createShader(activeRect);
      canvas.drawLine(Offset(startX, cy), Offset(thumbX, cy), activePaint);
    }

    // Halo externe du curseur rond
    canvas.drawCircle(
      Offset(thumbX, cy),
      thumbRadius + (isDragging ? 4.5 : 2.8),
      Paint()
        ..color = accentColor.withValues(alpha: isDragging ? 0.42 : 0.26),
    );

    // Curseur rond principal
    canvas.drawCircle(
      Offset(thumbX, cy),
      thumbRadius,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _CenteredLinearGaugePainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.accentColor != accentColor;
  }
}

/// ============================================================================
/// 3. RANGÉE DE TRANSPORT PRINCIPALE : 🔀  ⏮      ▶      ⏭  🔁
/// ============================================================================
class SonoritizSignatureTransportRow extends StatelessWidget {
  final bool isPlaying;
  final bool isBuffering;
  final bool isShuffleModeEnabled;
  final LoopMode loopMode;
  final ImmersivePalette palette;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;

  const SonoritizSignatureTransportRow({
    super.key,
    required this.isPlaying,
    required this.isBuffering,
    required this.isShuffleModeEnabled,
    required this.loopMode,
    required this.palette,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
  });

  Widget _buildModeButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isActive
                    ? palette.accentColor
                    : Colors.white.withValues(alpha: 0.72),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: isActive ? 4.5 : 0,
                height: isActive ? 4.5 : 0,
                decoration: BoxDecoration(
                  color: palette.accentColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Center(
            child: Icon(
              icon,
              size: 35,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isRepeatActive = loopMode != LoopMode.off;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildModeButton(
            icon: Icons.shuffle_rounded,
            tooltip: 'Aléatoire',
            isActive: isShuffleModeEnabled,
            onTap: onShuffle,
          ),
          _buildSkipButton(
            icon: Icons.skip_previous_rounded,
            tooltip: 'Précédent',
            onTap: onPrevious,
          ),
          // Bouton central Play / Pause entouré d'un fin liseré à la couleur de la pochette
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onPlayPause();
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.accentColor.withValues(alpha: 0.55),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.accentColor.withValues(alpha: 0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: isBuffering
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: RepaintBoundary(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: palette.deepColor,
                          ),
                        ),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 36,
                        color: const Color(0xFF101316),
                      ),
              ),
            ),
          ),
          _buildSkipButton(
            icon: Icons.skip_next_rounded,
            tooltip: 'Suivant',
            onTap: onNext,
          ),
          _buildModeButton(
            icon: loopMode == LoopMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            tooltip: 'Répéter',
            isActive: isRepeatActive,
            onTap: onRepeat,
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// 4. PILULE VERTICALE À DROITE (« RAIL D'ACTIONS SIGNATURE » COMME HALO ORBITAL) :
///    Regroupe de haut en bas :
///    1. Mode Vidéo  •  2. Favoris/Superlike  •  3. Paroles  •  4. File d'attente
///    5. Sortie Audio  •  6. Télécharger  •  7. Partager
/// ============================================================================
class SonoritizRightActionRail extends StatelessWidget {
  final TrackModel currentTrack;
  final ImmersivePalette palette;
  final bool isVideoMode;
  final bool isVideoLoading;
  final VoidCallback onToggleVideo;
  final VoidCallback onLyricsTapped;
  final VoidCallback onQueueTapped;
  final VoidCallback onDownloadFeedback;

  const SonoritizRightActionRail({
    super.key,
    required this.currentTrack,
    required this.palette,
    required this.isVideoMode,
    required this.isVideoLoading,
    required this.onToggleVideo,
    required this.onLyricsTapped,
    required this.onQueueTapped,
    required this.onDownloadFeedback,
  });

  Widget _horizontalHairline() {
    return Container(
      width: 18,
      height: 1,
      color: Colors.white.withValues(alpha: 0.14),
    );
  }

  Widget _railSlot({
    required Widget child,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 42,
          height: 35,
          child: Center(child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceService = AudioDeviceService();

    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Mode Vidéo / Clip
          _railSlot(
            tooltip: isVideoMode ? 'Mode audio' : 'Voir le clip',
            onTap: onToggleVideo,
            child: isVideoLoading
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: RepaintBoundary(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Icon(
                    isVideoMode
                        ? Icons.headphones_rounded
                        : Icons.play_circle_outline_rounded,
                    size: 19.5,
                    color: isVideoMode
                        ? palette.accentColor
                        : Colors.white.withValues(alpha: 0.92),
                  ),
          ),
          _horizontalHairline(),

          // 2. Favoris & Superlike (logo d'origine)
          PlayerFavoriteButton(
            track: currentTrack,
            size: 36,
            iconSize: 19,
          ),
          _horizontalHairline(),

          // 3. Paroles (Lyrics)
          _railSlot(
            tooltip: 'Paroles',
            onTap: onLyricsTapped,
            child: Icon(
              Icons.lyrics_outlined,
              size: 18.5,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          _horizontalHairline(),

          // 4. File d'attente
          _railSlot(
            tooltip: 'File d\'attente',
            onTap: onQueueTapped,
            child: Icon(
              Icons.queue_music_rounded,
              size: 19.5,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          _horizontalHairline(),

          // 5. Sortie Audio / Bluetooth
          StreamBuilder<AudioOutputDevice>(
            stream: deviceService.deviceStream,
            initialData: deviceService.currentDevice,
            builder: (context, snapshot) {
              final device = snapshot.data ?? deviceService.currentDevice;
              return _railSlot(
                tooltip: 'Sortie : ${device.name}',
                onTap: () => deviceService.openOutputSwitcher(),
                child: Icon(
                  device.isExternal ? device.icon : Icons.speaker_group_outlined,
                  size: 18.5,
                  color: device.isExternal
                      ? palette.accentColor
                      : Colors.white.withValues(alpha: 0.92),
                ),
              );
            },
          ),
          _horizontalHairline(),

          // 6. Télécharger
          BlocBuilder<DownloadCubit, DownloadState>(
            builder: (context, downloadState) {
              bool isDownloaded = false;
              bool isDownloading = false;
              if (downloadState is DownloadStateData) {
                isDownloaded =
                    downloadState.downloadedIds.contains(currentTrack.id);
                isDownloading = downloadState.downloadingProgress
                    .containsKey(currentTrack.id);
              }

              return _railSlot(
                tooltip: isDownloaded ? 'Téléchargé' : 'Télécharger',
                onTap: () {
                  if (currentTrack.id.startsWith('local_') || isDownloading) {
                    return;
                  }
                  if (isDownloaded) {
                    context
                        .read<DownloadCubit>()
                        .removeDownload(currentTrack.id);
                  } else {
                    context
                        .read<DownloadCubit>()
                        .downloadTrack(currentTrack);
                  }
                  onDownloadFeedback();
                },
                child: isDownloading
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: RepaintBoundary(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        isDownloaded
                            ? Icons.download_done_rounded
                            : Icons.download_outlined,
                        size: 19.0,
                        color: isDownloaded
                            ? palette.accentColor
                            : Colors.white.withValues(alpha: 0.92),
                      ),
              );
            },
          ),
          _horizontalHairline(),

          // 7. Partager
          _railSlot(
            tooltip: 'Partager',
            onTap: () => ShareUtils.shareTrack(
              currentTrack,
              context: context,
            ),
            child: Icon(
              Icons.ios_share_rounded,
              size: 18.0,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// 6. PETITS CADRES DES PROFILS D'ARTISTES CONCERNÉS PAR LE SON EN COURS
///    (Placés sous le double-cœur ; icône de profil vide grisée si pas d'image)
/// ============================================================================
class SonoritizTrackArtistsFrames extends StatefulWidget {
  final TrackModel track;
  final ImmersivePalette palette;

  const SonoritizTrackArtistsFrames({
    super.key,
    required this.track,
    required this.palette,
  });

  @override
  State<SonoritizTrackArtistsFrames> createState() =>
      _SonoritizTrackArtistsFramesState();
}

class _SonoritizTrackArtistsFramesState
    extends State<SonoritizTrackArtistsFrames> {
  static final Map<String, String> _avatarCache = <String, String>{};
  static final Map<String, String> _idCache = <String, String>{};
  static final dio_pkg.Dio _dio = dio_pkg.Dio(
    dio_pkg.BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
    ),
  );

  List<String> _artists = const [];
  final Map<String, String> _resolvedUrls = <String, String>{};
  final Map<String, String> _resolvedIds = <String, String>{};

  @override
  void initState() {
    super.initState();
    _syncArtistsForCurrentTrack();
  }

  @override
  void didUpdateWidget(covariant SonoritizTrackArtistsFrames oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id ||
        oldWidget.track.artistName != widget.track.artistName ||
        oldWidget.track.title != widget.track.title) {
      _syncArtistsForCurrentTrack();
    }
  }

  List<String> _parseTrackArtists(String rawArtistName, String rawTitle) {
    final RegExp separatorRegExp = RegExp(
      r'(\s+(?:feat\.?|ft\.?|featuring|and|&|x|\/)\s+|,\s+|\s*;\s*)',
      caseSensitive: false,
    );
    final RegExp bracketFeatRegExp = RegExp(
      r'[\(\[]\s*(?:feat\.?|ft\.?|featuring|with|avec)\s+([^\)\]]+)[\)\]]',
      caseSensitive: false,
    );

    // Normaliser « Artiste (feat. X) » en « Artiste feat. X »
    final String normalizedArtist = rawArtistName
        .replaceAllMapped(
          bracketFeatRegExp,
          (m) => ' feat. ${m.group(1)?.trim() ?? ''}',
        )
        .trim();

    final List<String> parts = normalizedArtist.split(separatorRegExp).toList();

    // Ajouter les invités éventuellement mentionnés uniquement dans le titre
    final titleMatch = bracketFeatRegExp.firstMatch(rawTitle);
    if (titleMatch != null && titleMatch.group(1) != null) {
      parts.addAll(titleMatch.group(1)!.split(separatorRegExp));
    }

    final List<String> result = [];
    for (final raw in parts) {
      final clean = raw
          .replaceAll(RegExp(r'^[\(\[\s]+|[\)\]\s]+$'), '')
          .replaceAll(
            RegExp(
              r'\s*(?:VEVO|- Topic|Topic|Official|Channel)\s*$',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      if (clean.isEmpty) continue;
      if (!result.any((a) => a.toLowerCase() == clean.toLowerCase())) {
        result.add(clean);
      }
      if (result.length >= 4) break;
    }
    if (result.isEmpty) {
      result.add('Artiste inconnu');
    }
    return result;
  }

  CatalogRepository _resolveCatalogRepo() {
    try {
      return context.read<CatalogRepository>();
    } catch (_) {
      return CatalogRepository();
    }
  }

  void _syncArtistsForCurrentTrack() {
    if (widget.track.isPodcastOrBook) {
      _artists = const [];
      _resolvedUrls.clear();
      _resolvedIds.clear();
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final parsed =
        _parseTrackArtists(widget.track.artistName, widget.track.title);
    _artists = parsed;
    _resolvedUrls.clear();
    _resolvedIds.clear();

    final List<String> toFetch = [];
    for (final artist in parsed) {
      final key = artist.toLowerCase();
      if (_idCache.containsKey(key) && _idCache[key]!.isNotEmpty) {
        _resolvedIds[artist] = _idCache[key]!;
      }
      if (_avatarCache.containsKey(key) && _avatarCache[key]!.isNotEmpty) {
        _resolvedUrls[artist] = _avatarCache[key]!;
        if (!_resolvedIds.containsKey(artist)) {
          toFetch.add(artist);
        }
      } else {
        toFetch.add(artist);
      }
    }
    if (mounted) {
      setState(() {});
    }
    if (toFetch.isNotEmpty) {
      _resolveArtistsWithTrackAndSearch(widget.track.id, toFetch);
    }
  }

  Future<void> _resolveArtistsWithTrackAndSearch(
    String trackId,
    List<String> artistsToFetch,
  ) async {
    final Set<String> resolvedLower = {};

    // 1. Si c'est un morceau Deezer, lire les `contributors` officiels du titre (zéro erreur d'homonyme)
    if (trackId.startsWith('deezer_') &&
        !trackId.startsWith('deezer_book_') &&
        !trackId.startsWith('deezer_pod_')) {
      final dzId = trackId.replaceFirst('deezer_', '').trim();
      try {
        final response = await _dio.get('https://api.deezer.com/track/$dzId');
        if (response.statusCode == 200 && response.data is Map) {
          final data = response.data as Map;
          final List<Map> rawArtists = [];
          if (data['contributors'] is List) {
            rawArtists.addAll((data['contributors'] as List).whereType<Map>());
          }
          if (data['artist'] is Map) {
            rawArtists.add(data['artist'] as Map);
          }
          for (final target in artistsToFetch) {
            final targetLower = target.toLowerCase().trim();
            for (final c in rawArtists) {
              final cName = (c['name'] ?? '').toString().toLowerCase().trim();
              if (cName == targetLower ||
                  (cName.isNotEmpty &&
                      (cName.contains(targetLower) ||
                          targetLower.contains(cName)))) {
                final rawPic = (c['picture_xl'] ??
                        c['picture_big'] ??
                        c['picture_medium'] ??
                        c['picture_small'] ??
                        c['picture'] ??
                        '')
                    .toString();
                final rawId = (c['id'] ?? '').toString().trim();
                if (rawId.isNotEmpty && rawId != '0') {
                  _idCache[targetLower] = rawId;
                }
                if (rawPic.isNotEmpty && !rawPic.contains('/images/artist//')) {
                  _avatarCache[targetLower] = rawPic;
                  resolvedLower.add(targetLower);
                  if (mounted && widget.track.id == trackId) {
                    setState(() {
                      _resolvedUrls[target] = rawPic;
                      if (rawId.isNotEmpty && rawId != '0') {
                        _resolvedIds[target] = rawId;
                      }
                    });
                  }
                  break;
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    // 2. Pour les artistes restants, utiliser le même moteur que la Recherche (nom exact + nb_fan décroissant)
    for (final artist in artistsToFetch) {
      if (resolvedLower.contains(artist.toLowerCase().trim())) continue;
      await _fetchArtistAvatar(artist, expectedTrackId: trackId);
    }
  }

  Future<void> _fetchArtistAvatar(
    String artistName, {
    String? expectedTrackId,
  }) async {
    final String key = artistName.toLowerCase().trim();
    if (key.isEmpty ||
        key == 'artiste inconnu' ||
        key == 'unknown artist') {
      if (mounted) {
        setState(() {
          _resolvedUrls[artistName] = '';
        });
      }
      return;
    }

    try {
      String foundPicture = '';
      String foundId = '';
      final repo = _resolveCatalogRepo();
      final results = await repo.searchArtists(artistName, limit: 10);
      if (results.isNotEmpty) {
        final top = results.first;
        final rawPic = (top['picture'] ?? '').toString();
        final rawId = (top['id'] ?? '').toString().trim();
        if (rawPic.isNotEmpty && !rawPic.contains('/images/artist//')) {
          foundPicture = rawPic;
        }
        if (rawId.isNotEmpty && rawId != '0') {
          foundId = rawId;
        }
      }

      if (_avatarCache.length >= 80) {
        _avatarCache.remove(_avatarCache.keys.first);
      }
      if (foundPicture.isNotEmpty) {
        _avatarCache[key] = foundPicture;
      }
      if (foundId.isNotEmpty) {
        _idCache[key] = foundId;
      }

      if (mounted &&
          (expectedTrackId == null || widget.track.id == expectedTrackId)) {
        setState(() {
          _resolvedUrls[artistName] = foundPicture;
          if (foundId.isNotEmpty) {
            _resolvedIds[artistName] = foundId;
          }
        });
      }
    } catch (_) {
      // Ne pas mettre en cache en cas d'erreur réseau temporaire afin de pouvoir réessayer
      if (mounted &&
          (expectedTrackId == null || widget.track.id == expectedTrackId)) {
        setState(() {
          _resolvedUrls[artistName] = '';
        });
      }
    }
  }

  void _openArtistProfile(BuildContext context, String artistName) {
    final clean = artistName.trim();
    if (clean.isEmpty || clean.toLowerCase() == 'artiste inconnu') return;
    HapticFeedback.lightImpact();
    final key = clean.toLowerCase();
    final resolvedId = _resolvedIds[artistName] ?? _idCache[key] ?? '';
    final resolvedUrl = _resolvedUrls[artistName] ?? _avatarCache[key] ?? '';
    final router = import_go_router.GoRouter.of(context);
    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route is! PopupRoute);
    router.push(
      '/artist',
      extra: <String, String>{
        'name': clean,
        if (resolvedId.isNotEmpty) 'id': resolvedId,
        if (resolvedUrl.isNotEmpty) 'imageUrl': resolvedUrl,
      },
    );
  }

  Widget _buildEmptyGreyProfileFallback() {
    return ColoredBox(
      color: const Color(0xFF23252B),
      child: Center(
        child: Icon(
          Icons.person_outline_rounded,
          size: 25,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  void _openPodcastVideoPage(BuildContext context) {
    HapticFeedback.mediumImpact();
    Duration resumePos = Duration.zero;
    try {
      final cubit = context.read<PlayerCubit>();
      resumePos = cubit.state.position;
      cubit.pause();
    } catch (_) {}

    final router = import_go_router.GoRouter.of(context);
    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route is! PopupRoute);
    router.push(
      '/podcast_player',
      extra: <String, dynamic>{
        'track': widget.track,
        'initialVideoMode': true,
        'initialPositionSeconds': resumePos.inSeconds,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Uniquement pour les Podcasts & Livres audio (jamais pour les sons musicaux) :
    // remplacer la photo de profil d'artiste par le bouton qui lance la page vidéo du podcast !
    if (widget.track.isPodcastOrBook) {
      return Tooltip(
        message: 'Lancer la vidéo',
        child: GestureDetector(
          onTap: () => _openPodcastVideoPage(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1B20).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.palette.accentColor.withValues(alpha: 0.55),
                width: 1.25,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.36),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.videocam_rounded,
                  color: widget.palette.accentColor,
                  size: 24,
                ),
                const SizedBox(width: 9),
                const Text(
                  'Voir la vidéo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < _artists.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Tooltip(
            message: _artists[i],
            child: GestureDetector(
              onTap: () => _openArtistProfile(context, _artists[i]),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF23252B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.30),
                    width: 1.25,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.36),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.6),
                  child: (_resolvedUrls[_artists[i]] ?? '').isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _resolvedUrls[_artists[i]]!,
                          fit: BoxFit.cover,
                          memCacheWidth: 160,
                          memCacheHeight: 160,
                          placeholder: (_, __) =>
                              _buildEmptyGreyProfileFallback(),
                          errorWidget: (_, __, ___) =>
                              _buildEmptyGreyProfileFallback(),
                        )
                      : _buildEmptyGreyProfileFallback(),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
