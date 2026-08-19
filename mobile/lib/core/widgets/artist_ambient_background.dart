import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ArtistAmbientBackground extends StatefulWidget {
  final Widget child;

  const ArtistAmbientBackground({Key? key, required this.child}) : super(key: key);

  @override
  State<ArtistAmbientBackground> createState() => _ArtistAmbientBackgroundState();
}

class _ArtistAmbientBackgroundState extends State<ArtistAmbientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25), // Très lent
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base sombre
        Container(color: AppColors.background),
        // Halos lumineux
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: AmbientBlobPainter(_controller.value),
              size: Size.infinite,
            );
          },
        ),
        // Flou intense pour unifier l'ambiance
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(color: Colors.transparent),
        ),
        // Contenu de la page au dessus
        widget.child,
      ],
    );
  }
}

class AmbientBlobPainter extends CustomPainter {
  final double progress;

  AmbientBlobPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Couleurs douces pour l'ambiance Artiste
    final paint1 = Paint()
      ..color = const Color(0xFF8A84E2).withOpacity(0.4) // Violet
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    final paint2 = Paint()
      ..color = const Color(0xFFFF5E5B).withOpacity(0.3) // Corail
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
      
    final paint3 = Paint()
      ..color = const Color(0xFF4A90E2).withOpacity(0.3) // Bleu
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    // Mouvement orbital très lent
    final x1 = size.width * (0.2 + 0.6 * sin(progress * pi * 2));
    final y1 = size.height * (0.2 + 0.3 * cos(progress * pi * 2));

    final x2 = size.width * (0.8 - 0.5 * cos(progress * pi * 2));
    final y2 = size.height * (0.5 + 0.3 * sin(progress * pi * 2));

    final x3 = size.width * (0.5 + 0.4 * sin(progress * pi * 2 + pi/2));
    final y3 = size.height * (0.8 - 0.2 * cos(progress * pi * 2 + pi/2));

    // Des cercles très grands pour couvrir l'écran
    canvas.drawCircle(Offset(x1, y1), size.width * 0.7, paint1);
    canvas.drawCircle(Offset(x2, y2), size.width * 0.8, paint2);
    canvas.drawCircle(Offset(x3, y3), size.width * 0.6, paint3);
  }

  @override
  bool shouldRepaint(covariant AmbientBlobPainter oldDelegate) => oldDelegate.progress != progress;
}
