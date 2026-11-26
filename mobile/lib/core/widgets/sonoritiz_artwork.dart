import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_dimensions.dart';

class SonoritizArtwork extends StatelessWidget {
  static final Map<String, bool> _localFileExistsCache = <String, bool>{};

  /// Vérifie l'existence d'un fichier local avec cache mémoire pour ne jamais bloquer le thread UI au scroll.
  static bool fileExistsCached(String path) {
    if (kIsWeb || path.isEmpty) return false;
    final clean = path.startsWith('file://')
        ? path.replaceFirst('file://', '')
        : path;
    final cached = _localFileExistsCache[clean];
    if (cached != null && cached) return true;
    final exists = File(clean).existsSync();
    if (_localFileExistsCache.length >= 400) {
      _localFileExistsCache.remove(_localFileExistsCache.keys.first);
    }
    _localFileExistsCache[clean] = exists;
    return exists;
  }

  /// Adapte la résolution de la pochette distante uniquement pour les toutes petites miniatures
  /// (conserve toujours le 1000x1000 HD sur le lecteur plein écran, les cartes et les vues double.infinity).
  static String _optimizeNetworkUrl(
    String url, {
    required double width,
    required double height,
    required int cacheMaxDimension,
  }) {
    if (!url.contains('1000x1000')) return url;
    // Si l'une des dimensions est infinie (ex: Lecteur Signature plein écran) ou cache HD demandé,
    // toujours garder l'URL originale 1000x1000 Ultra-HD !
    if (!width.isFinite || !height.isFinite || cacheMaxDimension >= 450) {
      return url;
    }
    final maxSide = width > height ? width : height;
    if (maxSide <= 72) {
      return url
          .replaceAll('/1000x1000-', '/250x250-')
          .replaceAll('1000x1000bb.jpg', '300x300bb.jpg');
    }
    if (maxSide <= 160) {
      return url
          .replaceAll('/1000x1000-', '/500x500-')
          .replaceAll('1000x1000bb.jpg', '500x500bb.jpg');
    }
    return url;
  }

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
        : ((height.isFinite && height > 0)
            ? height
            : cacheMaxDimension.toDouble());
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

    final Widget placeholderWidget = Container(
      width: width,
      height: height,
      color: const Color(0xFF17171E),
    );

    Widget imageWidget;
    final trimmedUrl = imageUrl.trim();

    if (trimmedUrl.isEmpty) {
      imageWidget = errorWidget;
    } else if (!kIsWeb && _isLocalPath(trimmedUrl)) {
      final cleanPath = trimmedUrl.startsWith('file://')
          ? trimmedUrl.replaceFirst('file://', '')
          : trimmedUrl;
      if (fileExistsCached(cleanPath)) {
        imageWidget = Image.file(
          File(cleanPath),
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
    } else if (trimmedUrl.startsWith('http://') ||
        trimmedUrl.startsWith('https://')) {
      final optimizedUrl = _optimizeNetworkUrl(
        trimmedUrl,
        width: width,
        height: height,
        cacheMaxDimension: cacheMaxDimension,
      );
      if (kIsWeb) {
        imageWidget = Image.network(
          optimizedUrl,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return placeholderWidget;
          },
          errorBuilder: (_, __, ___) => errorWidget,
        );
      } else {
        imageWidget = CachedNetworkImage(
          imageUrl: optimizedUrl,
          width: width,
          height: height,
          memCacheWidth: effectiveCacheWidth,
          memCacheHeight: effectiveCacheHeight,
          fit: fit,
          alignment: alignment,
          fadeInDuration: const Duration(milliseconds: 140),
          fadeOutDuration: const Duration(milliseconds: 80),
          placeholder: (context, url) => placeholderWidget,
          errorWidget: (context, url, error) => errorWidget,
        );
      }
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
