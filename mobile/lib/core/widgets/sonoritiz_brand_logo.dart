import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Variantes vectorielles du logo officiel Sonoritiz sur fond transparent.
enum SonoritizLogoVariant {
  /// Bécarre blanc + 8 cercles concentriques fins orange (#FA7921)
  standard,

  /// Bécarre blanc + 8 cercles concentriques fins blancs
  allWhite,

  /// Bécarre orange (#FA7921) + 8 cercles concentriques fins blancs
  orangeBecarreWhiteCircles,
}

/// Logo vectoriel officiel Sonoritiz fidèle à `logo_version_2.png` / `logo_transparent.png` :
/// - 8 anneaux concentriques continus d'épaisseur dégressive du centre vers l'extérieur,
/// - Bécarre géométrique plein à extrémités biseautées en diagonale et fenêtre parallélogramme,
/// - Détourage net autour du bécarre interrompant proprement les anneaux.
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

  Path _buildBecarrePath(double s, Offset origin) {
    Offset pt(double nx, double ny) =>
        Offset(origin.dx + nx * s, origin.dy + ny * s);

    // Contour extérieur exact du bécarre biseauté (sens horaire)
    final outer = Path()
      ..moveTo(pt(0.308, 0.144).dx, pt(0.308, 0.144).dy)
      ..lineTo(pt(0.378, 0.104).dx, pt(0.378, 0.104).dy)
      ..lineTo(pt(0.378, 0.364).dx, pt(0.378, 0.364).dy)
      ..lineTo(pt(0.662, 0.288).dx, pt(0.662, 0.288).dy)
      ..lineTo(pt(0.662, 0.856).dx, pt(0.662, 0.856).dy)
      ..lineTo(pt(0.592, 0.896).dx, pt(0.592, 0.896).dy)
      ..lineTo(pt(0.592, 0.636).dx, pt(0.592, 0.636).dy)
      ..lineTo(pt(0.308, 0.712).dx, pt(0.308, 0.712).dy)
      ..close();

    // Fenêtre intérieure en parallélogramme
    final innerWindow = Path()
      ..moveTo(pt(0.378, 0.436).dx, pt(0.378, 0.436).dy)
      ..lineTo(pt(0.592, 0.380).dx, pt(0.592, 0.380).dy)
      ..lineTo(pt(0.592, 0.564).dx, pt(0.592, 0.564).dy)
      ..lineTo(pt(0.378, 0.620).dx, pt(0.378, 0.620).dy)
      ..close();

    return Path.combine(PathOperation.difference, outer, innerWindow);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double s = math.min(size.width, size.height);
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Offset origin = Offset(center.dx - s / 2, center.dy - s / 2);

    final becarrePath = _buildBecarrePath(s, origin);

    canvas.saveLayer(Offset.zero & size, Paint());

    // 1. Les 8 anneaux concentriques continus (d'épaisseur dégressive vers l'extérieur)
    const List<double> radiiFactors = [
      0.218,
      0.252,
      0.286,
      0.320,
      0.354,
      0.388,
      0.422,
      0.456,
    ];
    final ringPaint = Paint()
      ..color = circlesColor
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    for (int i = 0; i < radiiFactors.length; i++) {
      final double r = s * radiiFactors[i];
      final double t = i / (radiiFactors.length - 1);
      ringPaint.strokeWidth = math.max(0.7, s * (0.0155 - t * 0.0085));
      canvas.drawCircle(center, r, ringPaint);
    }

    // 2. Détourage transparent net autour du bécarre (interrompt les anneaux comme sur le logo officiel)
    final cutoutPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.044
      ..strokeJoin = StrokeJoin.miter
      ..strokeMiterLimit = 10
      ..isAntiAlias = true;
    canvas.drawPath(becarrePath, cutoutPaint);

    final clearFillPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill;
    canvas.drawPath(becarrePath, clearFillPaint);

    // 3. Tracé plein du bécarre géométrique biseauté
    final fillPaint = Paint()
      ..color = becarreColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(becarrePath, fillPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SonoritizLogoPainter oldDelegate) =>
      oldDelegate.becarreColor != becarreColor ||
      oldDelegate.circlesColor != circlesColor;
}

/// Logo de Google (G 4 couleurs officiel) dessiné vectoriellement.
class GoogleLogoIcon extends StatelessWidget {
  final double size;

  const GoogleLogoIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = math.min(size.width, size.height);
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double stroke = s * 0.20;
    final double radius = (s - stroke) / 2;
    final Rect arcRect = Rect.fromCircle(center: c, radius: radius);

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Rouge (haut)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(arcRect, -2.35, 1.55, false, paint);

    // Jaune (gauche)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(arcRect, 2.30, 1.65, false, paint);

    // Vert (bas)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(arcRect, 0.72, 1.62, false, paint);

    // Bleu (droite + barre horizontale)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(arcRect, -0.18, 0.95, false, paint);

    final Paint barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        c.dx,
        c.dy - stroke * 0.48,
        radius + stroke * 0.48,
        stroke * 0.96,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
