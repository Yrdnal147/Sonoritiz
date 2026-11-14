import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_dimensions.dart';

class SonoritizArtwork extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;
  final Widget? fallbackIcon;
  final Alignment alignment;
  final BoxFit fit;
  final int cacheMaxDimension;

  const SonoritizArtwork({
    Key? key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius = AppDimensions.radiusMd,
    this.shape = BoxShape.rectangle,
    this.fallbackIcon,
    this.alignment = Alignment.center,
    this.fit = BoxFit.cover,
    this.cacheMaxDimension = 800,
  }) : super(key: key);

  bool _isLocalPath(String url) {
    return url.startsWith('file://') ||
        url.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(url);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    int? cacheDimension(double logicalSize) {
      if (!logicalSize.isFinite || logicalSize <= 0) return null;
      return (logicalSize * pixelRatio)
          .ceil()
          .clamp(1, cacheMaxDimension)
          .toInt();
    }

    final rawCacheWidth = cacheDimension(width);
    final rawCacheHeight = cacheDimension(height);
    // Toujours borner le décodage mémoire même quand width/height = double.infinity
    final int? effectiveCacheWidth =
        rawCacheWidth ?? (rawCacheHeight == null ? cacheMaxDimension : null);
    final int? effectiveCacheHeight = rawCacheHeight;

    final double finiteRef = (width.isFinite && width > 0)
        ? width
        : ((height.isFinite && height > 0) ? height : 100.0);
    final double safeIconSize = (finiteRef * 0.4).clamp(18.0, 64.0);

    final Widget errorWidget = Container(
      width: width,
      height: height,
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: fallbackIcon ??
            Icon(
              Icons.music_note_rounded,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              size: safeIconSize,
            ),
      ),
    );

    Widget imageWidget;
    final trimmedUrl = imageUrl.trim();

    if (trimmedUrl.isEmpty) {
      imageWidget = errorWidget;
    } else if (_isLocalPath(trimmedUrl)) {
      final cleanPath = trimmedUrl.startsWith('file://')
          ? trimmedUrl.replaceFirst('file://', '')
          : trimmedUrl;
      final file = File(cleanPath);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          width: width,
          height: height,
          cacheWidth: effectiveCacheWidth,
          cacheHeight: effectiveCacheHeight,
          fit: fit,
          alignment: alignment,
          errorBuilder: (_, __, ___) => errorWidget,
        );
      } else {
        imageWidget = errorWidget;
      }
    } else if (trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://')) {
      imageWidget = CachedNetworkImage(
        imageUrl: trimmedUrl,
        width: width,
        height: height,
        memCacheWidth: effectiveCacheWidth,
        memCacheHeight: effectiveCacheHeight,
        fit: fit,
        alignment: alignment,
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
    } else {
      imageWidget = errorWidget;
    }

    if (shape == BoxShape.circle) {
      return ClipOval(child: imageWidget);
    }

    if (borderRadius <= 0) {
      return imageWidget;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: imageWidget,
    );
  }
}
