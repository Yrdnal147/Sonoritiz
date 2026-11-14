import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Barre de progression musicale avec onde sinusoïdale animée fluide (style Android 13/14 / Pixel)
/// Teinte 100% blanche, avec gestion du tap et du glisser (scrubbing).
class WavyProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final bool isPlaying;
  final bool isSuperliked;
  final Color activeColor;
  final Color inactiveColor;
  final double waveHeight;
  final double trackHeight;
  final double thumbRadius;

  const WavyProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.isPlaying = true,
    this.isSuperliked = false,
    this.activeColor = Colors.white,
    this.inactiveColor = const Color(0x3DFFFFFF), // blanc 24%
    this.waveHeight = 8.0,
    this.trackHeight = 3.5,
    this.thumbRadius = 6.0,
  });

  @override
  State<WavyProgressBar> createState() => _WavyProgressBarState();
}

class _WavyProgressBarState extends State<WavyProgressBar> with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  double? _dragValue; // Pourcentage temporaire pendant le glisser

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    if (widget.isPlaying) {
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WavyProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_waveController.isAnimating) {
          _waveController.repeat();
        }
      } else {
        _waveController.stop();
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  double _getEffectiveFraction() {
    if (_dragValue != null) return _dragValue!.clamp(0.0, 1.0);
    final totalMs = widget.duration.inMilliseconds;
    if (totalMs <= 0) return 0.0;
    return (widget.position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  void _handleSeekFromDx(double dx, double width) {
    if (width <= 0) return;
    final fraction = (dx / width).clamp(0.0, 1.0);
    final totalMs = widget.duration.inMilliseconds;
    final targetMs = (fraction * totalMs).round();
    widget.onSeek(Duration(milliseconds: targetMs));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final totalHeight = widget.waveHeight * 2 + widget.thumbRadius * 2 + 8.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            _handleSeekFromDx(details.localPosition.dx, width);
          },
          onHorizontalDragStart: (details) {
            setState(() {
              _dragValue = (details.localPosition.dx / width).clamp(0.0, 1.0);
            });
          },
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragValue = (details.localPosition.dx / width).clamp(0.0, 1.0);
            });
          },
          onHorizontalDragEnd: (details) {
            if (_dragValue != null) {
              final totalMs = widget.duration.inMilliseconds;
              final targetMs = (_dragValue! * totalMs).round();
              widget.onSeek(Duration(milliseconds: targetMs));
              setState(() {
                _dragValue = null;
              });
            }
          },
          onHorizontalDragCancel: () {
            setState(() {
              _dragValue = null;
            });
          },
          child: SizedBox(
            height: totalHeight,
            width: width,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(width, totalHeight),
                    painter: _WavyProgressPainter(
                      fraction: _getEffectiveFraction(),
                      phase: _waveController.value * 2 * math.pi,
                      isPlaying: widget.isPlaying,
                      isSuperliked: widget.isSuperliked,
                      activeColor: widget.activeColor,
                      inactiveColor: widget.inactiveColor,
                      amplitude: widget.waveHeight * 0.5,
                      trackHeight: widget.trackHeight,
                      thumbRadius: widget.thumbRadius,
                      isDragging: _dragValue != null,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WavyProgressPainter extends CustomPainter {
  final double fraction;
  final double phase;
  final bool isPlaying;
  final bool isSuperliked;
  final Color activeColor;
  final Color inactiveColor;
  final double amplitude;
  final double trackHeight;
  final double thumbRadius;
  final bool isDragging;

  _WavyProgressPainter({
    required this.fraction,
    required this.phase,
    required this.isPlaying,
    required this.isSuperliked,
    required this.activeColor,
    required this.inactiveColor,
    required this.amplitude,
    required this.trackHeight,
    required this.thumbRadius,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final totalWidth = size.width;
    final playedWidth = (totalWidth * fraction).clamp(0.0, totalWidth);

    // 1. Piste inactive (portion non jouée)
    final inactivePaint = Paint()
      ..color = isSuperliked
          ? const Color(0x35FF6D00) // Lueur ambrée discrète en arrière-plan Superlike
          : inactiveColor
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final inactiveStartX = (playedWidth + thumbRadius * 0.5).clamp(0.0, totalWidth);
    if (inactiveStartX < totalWidth) {
      canvas.drawLine(
        Offset(inactiveStartX, centerY),
        Offset(totalWidth, centerY),
        inactivePaint,
      );
    }

    // 2. Portion jouée : onde vivante
    if (playedWidth > 0) {
      final wavePath = Path();
      final fillPath = Path();

      const startX = 0.0;
      final endX = playedWidth;

      wavePath.moveTo(startX, centerY);
      fillPath.moveTo(startX, centerY);

      const step = 2.0;

      if (isSuperliked) {
        // --- NOUVELLE ANIMATION : ONDE PULSAR SOLAIRE SUPERLIKE ---
        // Double harmonique fluide et vive sans latence CPU (Rouge Crimson -> Orange Intense -> Or Solaire)
        for (double x = startX; x <= endX; x += step) {
          double dampening = 1.0;
          if (x < 16.0) {
            dampening = x / 16.0;
          } else if (endX - x < 16.0) {
            dampening = (endX - x) / 16.0;
          }

          final currentAmp = isPlaying ? (amplitude * 1.1 * dampening) : (amplitude * 0.4 * dampening);
          final waveA = math.sin((x / 30.0) * 2 * math.pi - phase * 1.25);
          final waveB = math.sin((x / 15.0) * math.pi + phase * 0.85) * 0.35;
          final pulseFactor = (waveA + waveB) / 1.35;
          final y = centerY + pulseFactor * currentAmp;

          wavePath.lineTo(x, y);
          fillPath.lineTo(x, y);
        }
      } else {
        // --- ONDE STANDARD CALME (BLANCHE) ---
        const double wavelength = 46.0;
        for (double x = startX; x <= endX; x += step) {
          double dampening = 1.0;
          if (x < 16.0) {
            dampening = x / 16.0;
          } else if (endX - x < 18.0) {
            dampening = (endX - x) / 18.0;
          }

          final currentAmp = isPlaying ? (amplitude * dampening) : (amplitude * 0.45 * dampening);
          final y = centerY + math.sin((x / wavelength) * 2 * math.pi - phase) * currentAmp;

          wavePath.lineTo(x, y);
          fillPath.lineTo(x, y);
        }
      }

      fillPath.lineTo(endX, centerY);
      fillPath.lineTo(startX, centerY);
      fillPath.close();

      if (isSuperliked) {
        // Dégradé d'aura sous l'onde Superlike
        final fillShader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x40FF6D00), // Orange solaire intense
            Color(0x08FF1744), // Voile carmin
          ],
        ).createShader(Rect.fromLTWH(startX, centerY - amplitude * 2, math.max(endX - startX, 1.0), amplitude * 4));

        canvas.drawPath(fillPath, Paint()..shader = fillShader..style = PaintingStyle.fill);

        // Dégradé laser signature Sonoritiz Superlike : Rouge Crimson -> Orange Énergique -> Or Solaire
        final strokeShader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFFF1744), // Vibrant Red / Crimson
            Color(0xFFFF6D00), // Intense Orange
            Color(0xFFFFEA00), // Brilliant Yellow / Gold
          ],
          stops: [0.0, 0.60, 1.0],
        ).createShader(Rect.fromLTWH(startX, centerY - amplitude * 2, math.max(endX - startX, 1.0), amplitude * 4));

        final strokePaint = Paint()
          ..shader = strokeShader
          ..strokeWidth = trackHeight + 0.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;
        canvas.drawPath(wavePath, strokePaint);
      } else {
        // Remplissage sous l'onde (blanc translucide)
        final fillPaint = Paint()
          ..color = activeColor.withValues(alpha: 0.22)
          ..style = PaintingStyle.fill;
        canvas.drawPath(fillPath, fillPaint);

        // Ligne supérieure de l'onde (blanc pur)
        final strokePaint = Paint()
          ..color = activeColor
          ..strokeWidth = trackHeight + 0.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;
        canvas.drawPath(wavePath, strokePaint);
      }
    }

    // 3. Curseur (Thumb) au niveau de la tête de lecture
    if (isSuperliked) {
      // Halo pulsant d'énergie solaire au niveau de la tête de lecture
      final pulseFactor = 0.5 + 0.5 * math.sin(phase * 2.2);
      final glowRadius = thumbRadius + 2.5 + pulseFactor * 3.0;

      // Halo externe orangé
      canvas.drawCircle(
        Offset(playedWidth, centerY),
        glowRadius + (isDragging ? 3.0 : 0.0),
        Paint()..color = const Color(0xFFFF6D00).withValues(alpha: 0.32 + 0.18 * pulseFactor),
      );

      // Anneau intermédiaire rouge carmin
      canvas.drawCircle(
        Offset(playedWidth, centerY),
        thumbRadius + (isDragging ? 2.5 : 1.2),
        Paint()..color = const Color(0xFFFF1744),
      );

      // Noyau central or étincelant Superlike
      canvas.drawCircle(
        Offset(playedWidth, centerY),
        thumbRadius * 0.75,
        Paint()..color = const Color(0xFFFFEA00),
      );
    } else {
      final thumbPaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.fill;

      final thumbGlowPaint = Paint()
        ..color = activeColor.withValues(alpha: isDragging ? 0.35 : 0.20)
        ..style = PaintingStyle.fill;

      // Halo discret
      canvas.drawCircle(
        Offset(playedWidth, centerY),
        thumbRadius + (isDragging ? 4.0 : 2.0),
        thumbGlowPaint,
      );

      // Cercle principal blanc
      canvas.drawCircle(
        Offset(playedWidth, centerY),
        isDragging ? thumbRadius + 1.5 : thumbRadius,
        thumbPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavyProgressPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.phase != phase ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.isSuperliked != isSuperliked ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
