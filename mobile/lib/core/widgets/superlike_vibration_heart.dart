import 'dart:math' as math;
import 'package:flutter/material.dart';

enum SuperlikeBadgeSize {
  small,
  medium,
  large,
  xl,
}

/// Icône et badge officiel « Sonoritiz Superlike » :
/// Cœur vibrant entouré d'ondes acoustiques de pulsation.
class SuperlikeVibrationHeart extends StatelessWidget {
  final SuperlikeBadgeSize size;
  final bool showBackground;
  final bool animatePulse;
  final Color? color;
  final bool isActive;

  const SuperlikeVibrationHeart({
    Key? key,
    this.size = SuperlikeBadgeSize.small,
    this.showBackground = false,
    this.animatePulse = false,
    this.color,
    this.isActive = true,
  }) : super(key: key);

  static const List<Color> vibrationGradient = [
    Color(0xFFFFB300), // Gold
    Color(0xFFFF6D00), // Intense Orange
    Color(0xFFFF1744), // Crimson Vibration Accent
  ];

  @override
  Widget build(BuildContext context) {
    final double iconSize;
    final double boxSize;
    final double padding;

    switch (size) {
      case SuperlikeBadgeSize.small:
        iconSize = 14.0;
        boxSize = 24.0;
        padding = 3.5;
        break;
      case SuperlikeBadgeSize.medium:
        iconSize = 19.0;
        boxSize = 30.0;
        padding = 4.5;
        break;
      case SuperlikeBadgeSize.large:
        iconSize = 25.0;
        boxSize = 40.0;
        padding = 6.0;
        break;
      case SuperlikeBadgeSize.xl:
        iconSize = 32.0;
        boxSize = 52.0;
        padding = 8.0;
        break;
    }

    final Widget heartWidget = CustomPaint(
      size: Size(iconSize * 1.35, iconSize),
      painter: _VibrationHeartPainter(
        color: color,
        useGradient: color == null,
        isActive: isActive,
      ),
    );

    if (!showBackground) {
      return SizedBox(
        width: iconSize * 1.35,
        height: iconSize,
        child: heartWidget,
      );
    }

    return Container(
      width: boxSize * 1.15,
      height: boxSize,
      padding: EdgeInsets.symmetric(horizontal: padding * 1.2, vertical: padding),
      decoration: BoxDecoration(
        color: const Color(0xFF160D05).withOpacity(0.90),
        borderRadius: BorderRadius.circular(boxSize / 2),
        border: Border.all(
          color: const Color(0xFFFF9100).withOpacity(0.55),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6D00).withOpacity(0.35),
            blurRadius: 9,
            spreadRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(child: heartWidget),
    );
  }
}

/// Peintre vectoriel traçant le cœur central et les ondes de vibration latérales.
class _VibrationHeartPainter extends CustomPainter {
  final Color? color;
  final bool useGradient;
  final bool isActive;

  _VibrationHeartPainter({
    this.color,
    required this.useGradient,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double heartWidth = height * 0.92;
    final double heartHeight = height * 0.92;
    final double centerX = width / 2;
    final double centerY = height / 2;

    final Rect bounds = Rect.fromLTWH(0, 0, width, height);
    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final Paint wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    if (useGradient) {
      final shader = const LinearGradient(
        colors: SuperlikeVibrationHeart.vibrationGradient,
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(bounds);
      fillPaint.shader = shader;
      wavePaint.shader = shader;
    } else {
      fillPaint.color = color ?? const Color(0xFFFF9100);
      wavePaint.color = color ?? const Color(0xFFFF9100);
    }

    if (!isActive) {
      fillPaint.shader = null;
      fillPaint.color = Colors.white.withOpacity(0.35);
      wavePaint.shader = null;
      wavePaint.color = Colors.white.withOpacity(0.25);
    }

    // 1. Cœur central vectoriel
    final Path heartPath = Path();
    final double hx = centerX;
    final double hy = centerY - heartHeight * 0.05;
    final double w = heartWidth;
    final double h = heartHeight;

    heartPath.moveTo(hx, hy + h * 0.40);
    heartPath.cubicTo(
      hx - w * 0.65, hy - h * 0.15,
      hx - w * 0.45, hy - h * 0.55,
      hx, hy - h * 0.20,
    );
    heartPath.cubicTo(
      hx + w * 0.45, hy - h * 0.55,
      hx + w * 0.65, hy - h * 0.15,
      hx, hy + h * 0.40,
    );
    heartPath.close();

    canvas.drawPath(heartPath, fillPaint);

    // 2. Ondes de vibration acoustique (gauche et droite)
    wavePaint.strokeWidth = math.max(1.2, height * 0.09);

    // Onde gauche 1 (proche)
    final double leftX1 = centerX - w * 0.52;
    final Path waveL1 = Path()
      ..moveTo(leftX1, centerY - h * 0.25)
      ..quadraticBezierTo(leftX1 - w * 0.16, centerY, leftX1, centerY + h * 0.25);
    canvas.drawPath(waveL1, wavePaint);

    // Onde gauche 2 (externe)
    final double leftX2 = centerX - w * 0.72;
    final Path waveL2 = Path()
      ..moveTo(leftX2, centerY - h * 0.38)
      ..quadraticBezierTo(leftX2 - w * 0.22, centerY, leftX2, centerY + h * 0.38);
    canvas.drawPath(waveL2, wavePaint);

    // Onde droite 1 (proche)
    final double rightX1 = centerX + w * 0.52;
    final Path waveR1 = Path()
      ..moveTo(rightX1, centerY - h * 0.25)
      ..quadraticBezierTo(rightX1 + w * 0.16, centerY, rightX1, centerY + h * 0.25);
    canvas.drawPath(waveR1, wavePaint);

    // Onde droite 2 (externe)
    final double rightX2 = centerX + w * 0.72;
    final Path waveR2 = Path()
      ..moveTo(rightX2, centerY - h * 0.38)
      ..quadraticBezierTo(rightX2 + w * 0.22, centerY, rightX2, centerY + h * 0.38);
    canvas.drawPath(waveR2, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _VibrationHeartPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.useGradient != useGradient ||
        oldDelegate.isActive != isActive;
  }
}
