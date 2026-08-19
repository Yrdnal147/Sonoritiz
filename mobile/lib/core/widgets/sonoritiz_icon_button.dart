import 'package:flutter/material.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_animations.dart';

class SonoritizIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final double iconSize;

  const SonoritizIconButton({
    Key? key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
    this.backgroundColor,
    this.size = AppDimensions.minTouchTarget,
    this.iconSize = AppDimensions.iconMd,
  }) : super(key: key);

  @override
  State<SonoritizIconButton> createState() => _SonoritizIconButtonState();
}

class _SonoritizIconButtonState extends State<SonoritizIconButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.standard),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = widget.color ?? colorScheme.onSurface;

    return Semantics(
      button: true,
      label: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) {
            _controller.reverse();
            widget.onPressed();
          },
          onTapCancel: () => _controller.reverse(),
          behavior: HitTestBehavior.opaque,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  widget.icon,
                  color: iconColor,
                  size: widget.iconSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
