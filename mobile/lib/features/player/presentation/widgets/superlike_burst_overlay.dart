import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/superlike_vibration_heart.dart';

class SuperlikeBurstOverlay extends StatefulWidget {
  final Widget? child;

  const SuperlikeBurstOverlay({
    Key? key,
    this.child,
  }) : super(key: key);

  @override
  SuperlikeBurstOverlayState createState() => SuperlikeBurstOverlayState();
}

class SuperlikeBurstOverlayState extends State<SuperlikeBurstOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _pulseAnimation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.1, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.05)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.15)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
    ]).animate(_controller);

    _pulseAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _isAnimating = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void trigger() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isAnimating = true;
    });
    _controller.forward(from: 0.0);
  }

  Widget _buildBurstGraphic() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ondes acoustiques concentriques rayonnant vers l'extérieur
                CustomPaint(
                  size: const Size(220, 220),
                  painter: _AcousticPulseRingsPainter(
                    progress: _pulseAnimation.value,
                  ),
                ),
                // Cœur vibrant central avec halo doré
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF140702).withOpacity(0.85),
                      border: Border.all(
                        color: const Color(0xFFFFD600).withOpacity(0.85),
                        width: 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3D00).withOpacity(0.75),
                          blurRadius: 36,
                          spreadRadius: 6,
                        ),
                        BoxShadow(
                          color: const Color(0xFFFFD600).withOpacity(0.50),
                          blurRadius: 54,
                          spreadRadius: 12,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: SuperlikeVibrationHeart(
                        size: SuperlikeBadgeSize.xl,
                        showBackground: false,
                        isActive: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.child == null) {
      if (!_isAnimating) return const SizedBox.shrink();
      return IgnorePointer(child: _buildBurstGraphic());
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.child != null) widget.child!,
        if (_isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: _buildBurstGraphic(),
            ),
          ),
      ],
    );
  }
}

/// Ondes acoustiques concentriques de vibration (remplace les étincelles artificielles)
class _AcousticPulseRingsPainter extends CustomPainter {
  final double progress;

  _AcousticPulseRingsPainter({required this.progress});

  static const List<Color> ringColors = [
    Color(0xFFFFB300),
    Color(0xFFFF6D00),
    Color(0xFFFF1744),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress - (i * 0.18)).clamp(0.0, 1.0);
      if (ringProgress <= 0.0) continue;

      final radius = 52.0 + ringProgress * (maxRadius - 52.0);
      final opacity = (1.0 - ringProgress).clamp(0.0, 1.0) * 0.75;
      final color = ringColors[i % ringColors.length];

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, (1.0 - ringProgress) * 3.5);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AcousticPulseRingsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
