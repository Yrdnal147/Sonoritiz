import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FestiveBackground extends StatelessWidget {
  final Widget child;

  const FestiveBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.15),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 100, spreadRadius: 50),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          left: -50,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.purpleAccent.withOpacity(0.15),
              boxShadow: [
                BoxShadow(color: Colors.purpleAccent.withOpacity(0.2), blurRadius: 100, spreadRadius: 50),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
