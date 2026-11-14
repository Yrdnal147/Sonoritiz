import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Variantes vectorielles du logo Sonoritiz sur fond totalement transparent.
enum SonoritizLogoVariant {
  /// Bécarre blanc + cercles concentriques brisés orange (#FF6B00)
  standard,

  /// Bécarre blanc + cercles concentriques brisés blancs
  allWhite,

  /// Bécarre orange (#FF6B00) + cercles concentriques brisés blancs
  orangeBecarreWhiteCircles,
}

/// Logo vectoriel Sonoritiz sans fond noir, sans cadre et sans lueur.
class SonoritizVectorLogo extends StatelessWidget {
  final double size;
  final SonoritizLogoVariant variant;
  final double opacity;

  const SonoritizVectorLogo({
    super.key,
    this.size = 96,
    this.variant = SonoritizLogoVariant.standard,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final Color becarreColor;
    final Color circlesColor;

    switch (variant) {
      case SonoritizLogoVariant.standard:
        becarreColor = Colors.white;
        circlesColor = AppColors.primary;
        break;
      case SonoritizLogoVariant.allWhite:
        becarreColor = Colors.white;
        circlesColor = Colors.white;
        break;
      case SonoritizLogoVariant.orangeBecarreWhiteCircles:
        becarreColor = AppColors.primary;
        circlesColor = Colors.white;
        break;
    }

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _SonoritizLogoPainter(
            becarreColor: becarreColor,
            circlesColor: circlesColor,
          ),
        ),
      ),
    );
  }
}

class _SonoritizLogoPainter extends CustomPainter {
  final Color becarreColor;
  final Color circlesColor;

  const _SonoritizLogoPainter({
    required this.becarreColor,
    required this.circlesColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double s = math.min(size.width, size.height);
    final Offset center = Offset(size.width / 2, size.height / 2);

    // 1. Cercles concentriques brisés (onde sonore Sonoritiz)
    const List<double> radiiFactors = [0.23, 0.30, 0.37, 0.44, 0.50];
    final ringPaint = Paint()
      ..color = circlesColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < radiiFactors.length; i++) {
      final double r = s * radiiFactors[i];
      ringPaint.strokeWidth = math.max(1.1, s * (0.022 - i * 0.0014));
      final rect = Rect.fromCircle(center: center, radius: r);
      final double rot = (i.isEven ? 0.18 : -0.26) + (i * 0.22);

      // Deux arcs symétriques brisés laissant respirer la forme centrale
      canvas.drawArc(rect, rot, math.pi * 0.68, false, ringPaint);
      canvas.drawArc(rect, rot + math.pi, math.pi * 0.68, false, ringPaint);
    }

    // 2. Bécarre musical central net et équilibré
    final stemWidth = math.max(1.6, s * 0.058);
    final barThickness = math.max(1.8, s * 0.068);
    final double boxHalfW = s * 0.095;
    final double boxHalfH = s * 0.088;
    final double skew = s * 0.026;

    final stemPaint = Paint()
      ..color = becarreColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stemWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Montant gauche (monte haut)
    canvas.drawLine(
      Offset(center.dx - boxHalfW, center.dy - s * 0.22),
      Offset(center.dx - boxHalfW, center.dy + boxHalfH),
      stemPaint,
    );

    // Montant droit (descend bas)
    canvas.drawLine(
      Offset(center.dx + boxHalfW, center.dy - boxHalfH),
      Offset(center.dx + boxHalfW, center.dy + s * 0.22),
      stemPaint,
    );

    // Barres transversales légèrement obliques du bécarre (♮)
    final barPaint = Paint()
      ..color = becarreColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = barThickness
      ..strokeCap = StrokeCap.butt;

    canvas.drawLine(
      Offset(center.dx - boxHalfW - stemWidth * 0.15, center.dy - boxHalfH + skew),
      Offset(center.dx + boxHalfW + stemWidth * 0.15, center.dy - boxHalfH - skew * 0.35),
      barPaint,
    );

    canvas.drawLine(
      Offset(center.dx - boxHalfW - stemWidth * 0.15, center.dy + boxHalfH + skew * 0.35),
      Offset(center.dx + boxHalfW + stemWidth * 0.15, center.dy + boxHalfH - skew),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SonoritizLogoPainter oldDelegate) =>
      oldDelegate.becarreColor != becarreColor ||
      oldDelegate.circlesColor != circlesColor;
}

/// Véritable icône Google "G" à 4 couleurs officielles (#4285F4, #34A853, #FBBC05, #EA4335).
class GoogleLogoIcon extends StatelessWidget {
  final double size;

  const GoogleLogoIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = math.min(size.width, size.height);
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double radius = s * 0.40;
    final double strokeWidth = s * 0.20;
    final Rect oval = Rect.fromCircle(center: c, radius: radius);

    Paint strokePaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Rouge (haut)
    canvas.drawArc(
      oval,
      -math.pi * 0.78,
      math.pi * 0.56,
      false,
      strokePaint(const Color(0xFFEA4335)),
    );

    // Jaune (gauche)
    canvas.drawArc(
      oval,
      math.pi * 0.78,
      math.pi * 0.44,
      false,
      strokePaint(const Color(0xFFFBBC05)),
    );

    // Vert (bas)
    canvas.drawArc(
      oval,
      math.pi * 0.14,
      math.pi * 0.64,
      false,
      strokePaint(const Color(0xFF34A853)),
    );

    // Bleu (arc droit)
    canvas.drawArc(
      oval,
      -0.06,
      math.pi * 0.22,
      false,
      strokePaint(const Color(0xFF4285F4)),
    );

    // Barre horizontale bleue du G
    final barRect = Rect.fromLTWH(
      c.dx - s * 0.02,
      c.dy - strokeWidth * 0.50,
      radius + strokeWidth * 0.48,
      strokeWidth,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, Radius.circular(strokeWidth * 0.15)),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
