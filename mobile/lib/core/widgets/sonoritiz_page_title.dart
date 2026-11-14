import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SonoritizPageTitle extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final int maxLines;
  final bool centered;
  final Color underlineColor;

  const SonoritizPageTitle({
    super.key,
    required this.title,
    this.padding = EdgeInsets.zero,
    this.fontSize = 28,
    this.maxLines = 1,
    this.centered = false,
    this.underlineColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompact = fontSize <= 22;

    return Padding(
      padding: padding,
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
            SizedBox(height: isCompact ? 3 : 5),
            Align(
              alignment: centered ? Alignment.center : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 32),
                  height: isCompact ? 2.5 : 3,
                  decoration: BoxDecoration(
                    color: underlineColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
