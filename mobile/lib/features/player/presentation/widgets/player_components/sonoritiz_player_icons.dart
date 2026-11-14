import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Icones personnalisées Sonoritiz au style néo-minimaliste, géométrique et haute précision.
/// Dessinées via CustomPainter pour une netteté absolue et une identité visuelle unique.

class SonoritizPlayIcon extends StatelessWidget {
  final double size;
  final Color color;

  const SonoritizPlayIcon({
    super.key,
    this.size = 28,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PlayIconPainter(color: color),
    );
  }
}

class _PlayIconPainter extends CustomPainter {
  final Color color;
  _PlayIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Triangle aux sommets adoucis
    final path = Path();
    final r = w * 0.08;
    final p1 = Offset(w * 0.28, h * 0.18);
    final p2 = Offset(w * 0.82, h * 0.50);
    final p3 = Offset(w * 0.28, h * 0.82);

    path.moveTo(p1.dx + r, p1.dy);
    path.lineTo(p2.dx - r * 1.5, p2.dy - r);
    path.quadraticBezierTo(p2.dx, p2.dy, p2.dx - r * 1.5, p2.dy + r);
    path.lineTo(p3.dx + r, p3.dy);
    path.quadraticBezierTo(p3.dx, p3.dy, p3.dx, p3.dy - r);
    path.lineTo(p1.dx, p1.dy + r);
    path.quadraticBezierTo(p1.dx, p1.dy, p1.dx + r, p1.dy);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PlayIconPainter old) => old.color != color;
}

class SonoritizPauseIcon extends StatelessWidget {
  final double size;
  final Color color;

  const SonoritizPauseIcon({
    super.key,
    this.size = 28,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PauseIconPainter(color: color),
    );
  }
}

class _PauseIconPainter extends CustomPainter {
  final Color color;
  _PauseIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final barW = w * 0.18;
    final barH = h * 0.60;
    final top = (h - barH) / 2;
    final radius = Radius.circular(barW / 2);

    // Barre gauche
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.26, top, barW, barH), radius),
      paint,
    );
    // Barre droite
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.56, top, barW, barH), radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PauseIconPainter old) => old.color != color;
}

class SonoritizPrevIcon extends StatelessWidget {
  final double size;
  final Color color;

  const SonoritizPrevIcon({
    super.key,
    this.size = 26,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PrevIconPainter(color: color),
    );
  }
}

class _PrevIconPainter extends CustomPainter {
  final Color color;
  _PrevIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Barre d'arrêt verticale gauche
    final barW = w * 0.11;
    final barH = h * 0.54;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, (h - barH) / 2, barW, barH),
        Radius.circular(barW / 2),
      ),
      paint,
    );

    // Flèche triangle gauche
    final path = Path();
    path.moveTo(w * 0.78, h * 0.22);
    path.lineTo(w * 0.35, h * 0.50);
    path.lineTo(w * 0.78, h * 0.78);
    path.close();

    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _PrevIconPainter old) => old.color != color;
}

class SonoritizNextIcon extends StatelessWidget {
  final double size;
  final Color color;

  const SonoritizNextIcon({
    super.key,
    this.size = 26,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _NextIconPainter(color: color),
    );
  }
}

class _NextIconPainter extends CustomPainter {
  final Color color;
  _NextIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Flèche triangle droite
    final path = Path();
    path.moveTo(w * 0.22, h * 0.22);
    path.lineTo(w * 0.65, h * 0.50);
    path.lineTo(w * 0.22, h * 0.78);
    path.close();

    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, arrowPaint);

    // Barre d'arrêt verticale droite
    final barW = w * 0.11;
    final barH = h * 0.54;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.75, (h - barH) / 2, barW, barH),
        Radius.circular(barW / 2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _NextIconPainter old) => old.color != color;
}

class SonoritizShuffleIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool isActive;

  const SonoritizShuffleIcon({
    super.key,
    this.size = 22,
    this.color = Colors.white,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ShuffleIconPainter(color: color, isActive: isActive),
    );
  }
}

class _ShuffleIconPainter extends CustomPainter {
  final Color color;
  final bool isActive;
  _ShuffleIconPainter({required this.color, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Courbe 1 : de gauche haut vers droite bas
    final p1 = Path();
    p1.moveTo(w * 0.16, h * 0.32);
    p1.lineTo(w * 0.32, h * 0.32);
    p1.cubicTo(w * 0.48, h * 0.32, w * 0.56, h * 0.68, w * 0.72, h * 0.68);
    p1.lineTo(w * 0.82, h * 0.68);
    canvas.drawPath(p1, linePaint);

    // Pointe flèche bas droite
    final a1 = Path();
    a1.moveTo(w * 0.84, h * 0.68);
    a1.lineTo(w * 0.72, h * 0.58);
    a1.lineTo(w * 0.72, h * 0.78);
    a1.close();
    canvas.drawPath(a1, fillPaint);

    // Courbe 2 : de gauche bas vers droite haut (avec saut)
    final p2a = Path();
    p2a.moveTo(w * 0.16, h * 0.68);
    p2a.lineTo(w * 0.32, h * 0.68);
    p2a.cubicTo(w * 0.40, h * 0.68, w * 0.44, h * 0.58, w * 0.47, h * 0.53);
    canvas.drawPath(p2a, linePaint);

    final p2b = Path();
    p2b.moveTo(w * 0.57, h * 0.45);
    p2b.cubicTo(w * 0.60, h * 0.40, w * 0.64, h * 0.32, w * 0.72, h * 0.32);
    p2b.lineTo(w * 0.82, h * 0.32);
    canvas.drawPath(p2b, linePaint);

    // Pointe flèche haut droite
    final a2 = Path();
    a2.moveTo(w * 0.84, h * 0.32);
    a2.lineTo(w * 0.72, h * 0.22);
    a2.lineTo(w * 0.72, h * 0.42);
    a2.close();
    canvas.drawPath(a2, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _ShuffleIconPainter old) =>
      old.color != color || old.isActive != isActive;
}

class SonoritizRepeatIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool isActive;
  final bool isOne;

  const SonoritizRepeatIcon({
    super.key,
    this.size = 22,
    this.color = Colors.white,
    this.isActive = false,
    this.isOne = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _RepeatIconPainter(color: color, isActive: isActive, isOne: isOne),
    );
  }
}

class _RepeatIconPainter extends CustomPainter {
  final Color color;
  final bool isActive;
  final bool isOne;

  _RepeatIconPainter({
    required this.color,
    required this.isActive,
    required this.isOne,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Anneau de répétition arrondi
    final rect = Rect.fromCenter(
      center: Offset(w * 0.50, h * 0.50),
      width: w * 0.64,
      height: h * 0.56,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.22));

    final loopPath = Path();
    loopPath.addRRect(rrect);
    canvas.drawPath(loopPath, linePaint);

    // Pointe de flèche en haut à droite
    final arrow = Path();
    arrow.moveTo(w * 0.78, h * 0.22);
    arrow.lineTo(w * 0.62, h * 0.12);
    arrow.lineTo(w * 0.66, h * 0.32);
    arrow.close();
    canvas.drawPath(arrow, fillPaint);

    if (isOne) {
      // Point lumineux au centre pour 'Répéter 1'
      canvas.drawCircle(Offset(w * 0.50, h * 0.50), w * 0.08, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RepeatIconPainter old) =>
      old.color != color || old.isActive != isActive || old.isOne != isOne;
}

class SonoritizHeartIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool isFilled;

  const SonoritizHeartIcon({
    super.key,
    this.size = 22,
    this.color = Colors.white,
    this.isFilled = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _HeartIconPainter(color: color, isFilled: isFilled),
    );
  }
}

class _HeartIconPainter extends CustomPainter {
  final Color color;
  final bool isFilled;

  _HeartIconPainter({required this.color, required this.isFilled});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(w * 0.50, h * 0.82);
    path.cubicTo(w * 0.18, h * 0.62, w * 0.08, h * 0.38, w * 0.24, h * 0.22);
    path.cubicTo(w * 0.38, h * 0.08, w * 0.48, h * 0.18, w * 0.50, h * 0.30);
    path.cubicTo(w * 0.52, h * 0.18, w * 0.62, h * 0.08, w * 0.76, h * 0.22);
    path.cubicTo(w * 0.92, h * 0.38, w * 0.82, h * 0.62, w * 0.50, h * 0.82);
    path.close();

    if (isFilled) {
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    } else {
      final strokePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeartIconPainter old) =>
      old.color != color || old.isFilled != isFilled;
}

class SonoritizLyricsIcon extends StatelessWidget {
  final double size;
  final Color color;

  const SonoritizLyricsIcon({
    super.key,
    this.size = 18,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _LyricsIconPainter(color: color),
    );
  }
}

class _LyricsIconPainter extends CustomPainter {
  final Color color;
  _LyricsIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    // 3 lignes de texte / ondes fluides
    canvas.drawLine(Offset(w * 0.20, h * 0.28), Offset(w * 0.70, h * 0.28), paint);
    canvas.drawLine(Offset(w * 0.20, h * 0.50), Offset(w * 0.82, h * 0.50), paint);
    canvas.drawLine(Offset(w * 0.20, h * 0.72), Offset(w * 0.54, h * 0.72), paint);

    // Note de musique stylisée en bas à droite
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.78, h * 0.74), w * 0.08, dotPaint);
    final noteStem = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.84, h * 0.74), Offset(w * 0.84, h * 0.62), noteStem);
  }

  @override
  bool shouldRepaint(covariant _LyricsIconPainter old) => old.color != color;
}

class SonoritizQueueIcon extends StatelessWidget {
  final double size;
  final Color color;

  const SonoritizQueueIcon({
    super.key,
    this.size = 18,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _QueueIconPainter(color: color),
    );
  }
}

class _QueueIconPainter extends CustomPainter {
  final Color color;
  _QueueIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    // 3 lignes étagées élégantes
    canvas.drawLine(Offset(w * 0.44, h * 0.30), Offset(w * 0.84, h * 0.30), paint);
    canvas.drawLine(Offset(w * 0.44, h * 0.50), Offset(w * 0.84, h * 0.50), paint);
    canvas.drawLine(Offset(w * 0.20, h * 0.70), Offset(w * 0.84, h * 0.70), paint);

    // Mini chevron Play devant les 2 premières lignes
    final playPath = Path();
    playPath.moveTo(w * 0.18, h * 0.28);
    playPath.lineTo(w * 0.32, h * 0.40);
    playPath.lineTo(w * 0.18, h * 0.52);
    playPath.close();

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(playPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _QueueIconPainter old) => old.color != color;
}

class SonoritizVideoIcon extends StatelessWidget {
  final double size;
  final Color color;

  const SonoritizVideoIcon({
    super.key,
    this.size = 18,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _VideoIconPainter(color: color),
    );
  }
}

class _VideoIconPainter extends CustomPainter {
  final Color color;
  _VideoIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    // Écran cinéma arrondi
    final screenRect = Rect.fromLTWH(w * 0.14, h * 0.22, w * 0.56, h * 0.56);
    canvas.drawRRect(
      RRect.fromRectAndRadius(screenRect, Radius.circular(w * 0.12)),
      strokePaint,
    );

    // Objectif / cône de projection à droite
    final cone = Path();
    cone.moveTo(w * 0.72, h * 0.38);
    cone.lineTo(w * 0.88, h * 0.28);
    cone.lineTo(w * 0.88, h * 0.72);
    cone.lineTo(w * 0.72, h * 0.62);
    cone.close();

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(cone, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _VideoIconPainter old) => old.color != color;
}

class SonoritizDownloadIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool isCompleted;

  const SonoritizDownloadIcon({
    super.key,
    this.size = 18,
    this.color = Colors.white,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _DownloadIconPainter(color: color, isCompleted: isCompleted),
    );
  }
}

class _DownloadIconPainter extends CustomPainter {
  final Color color;
  final bool isCompleted;
  _DownloadIconPainter({required this.color, required this.isCompleted});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Plateau d'accueil inférieur arrondi
    final tray = Path();
    tray.moveTo(w * 0.18, h * 0.62);
    tray.lineTo(w * 0.18, h * 0.76);
    tray.quadraticBezierTo(w * 0.18, h * 0.82, w * 0.26, h * 0.82);
    tray.lineTo(w * 0.74, h * 0.82);
    tray.quadraticBezierTo(w * 0.82, h * 0.82, w * 0.82, h * 0.76);
    tray.lineTo(w * 0.82, h * 0.62);
    canvas.drawPath(tray, strokePaint);

    if (isCompleted) {
      // Checkmark stylisé
      final check = Path();
      check.moveTo(w * 0.32, h * 0.44);
      check.lineTo(w * 0.46, h * 0.58);
      check.lineTo(w * 0.72, h * 0.28);
      canvas.drawPath(check, strokePaint);
    } else {
      // Flèche vers le bas
      canvas.drawLine(Offset(w * 0.50, h * 0.20), Offset(w * 0.50, h * 0.58), strokePaint);
      final arrow = Path();
      arrow.moveTo(w * 0.34, h * 0.44);
      arrow.lineTo(w * 0.50, h * 0.60);
      arrow.lineTo(w * 0.66, h * 0.44);
      canvas.drawPath(arrow, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DownloadIconPainter old) =>
      old.color != color || old.isCompleted != isCompleted;
}
