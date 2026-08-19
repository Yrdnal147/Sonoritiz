import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

class SonoritizArtwork extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;
  final Widget? fallbackIcon;

  const SonoritizArtwork({
    Key? key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius = AppDimensions.radiusMd,
    this.shape = BoxShape.rectangle,
    this.fallbackIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget errorWidget = Container(
      width: width,
      height: height,
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: fallbackIcon ?? Icon(
          Icons.music_note_rounded,
          color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          size: width * 0.4,
        ),
      ),
    );

    Widget imageWidget;

    if (imageUrl.isEmpty) {
      imageWidget = errorWidget;
    } else if (imageUrl.startsWith('file://')) {
      final file = File(imageUrl.replaceFirst('file://', ''));
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => errorWidget,
        );
      } else {
        imageWidget = errorWidget;
      }
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: colorScheme.surfaceContainerHighest,
          highlightColor: colorScheme.surface,
          child: Container(
            width: width,
            height: height,
            color: colorScheme.surfaceContainerHighest,
          ),
        ),
        errorWidget: (context, url, error) => errorWidget,
      );
    }

    if (shape == BoxShape.circle) {
      return ClipOval(child: imageWidget);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: imageWidget,
    );
  }
}
