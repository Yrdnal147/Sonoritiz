import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../features/player/presentation/widgets/player_components/immersive_player_widgets.dart';

/// Service unifié d'extraction de palette chromatique pour toute l'application
/// (Mini-lecteur, Lecteur plein écran, Sonoritiz Lyrics, Shorts, Sélections).
/// - Cache LRU partagé (220 entrées)
/// - Déduplication des extractions en cours (_inFlight)
/// - Échantillonnage miniature 32x32 sur URL allégée (250x250) pour diviser par 4 le coût CPU.
class PaletteService {
  static final Map<String, ImmersivePalette> _cache = <String, ImmersivePalette>{};
  static final Map<String, Future<ImmersivePalette>> _inFlight =
      <String, Future<ImmersivePalette>>{};

  static String _normalizeKey(String coverUrl) {
    final trimmed = coverUrl.trim();
    if (trimmed.isEmpty) return '';
    return trimmed
        .replaceAll('/1000x1000-', '/250x250-')
        .replaceAll('/500x500-', '/250x250-')
        .replaceAll('1000x1000bb.jpg', '300x300bb.jpg');
  }

  /// Retourne immédiatement la palette mise en cache si déjà extraite.
  static ImmersivePalette? getCached(String coverUrl) {
    final trimmed = coverUrl.trim();
    if (trimmed.isEmpty) return null;
    return _cache[trimmed] ?? _cache[_normalizeKey(trimmed)];
  }

  static void _storeInCache(String rawUrl, String normUrl, ImmersivePalette palette) {
    if (_cache.length >= 220) {
      _cache.remove(_cache.keys.first);
    }
    _cache[rawUrl] = palette;
    if (normUrl.isNotEmpty && normUrl != rawUrl) {
      _cache[normUrl] = palette;
    }
  }

  /// Récupère ou génère la palette immersive à partir d'une URL de pochette (avec cache LRU et déduplication).
  static Future<ImmersivePalette> getPalette(String coverUrl) {
    final trimmed = coverUrl.trim();
    if (trimmed.isEmpty) return Future.value(ImmersivePalette.fallback);

    final cached = getCached(trimmed);
    if (cached != null) {
      return Future.value(cached);
    }

    final normKey = _normalizeKey(trimmed);
    final existingFuture = _inFlight[normKey];
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _extractPaletteInternal(trimmed, normKey).whenComplete(() {
      _inFlight.remove(normKey);
    });
    _inFlight[normKey] = future;
    return future;
  }

  static Future<ImmersivePalette> _extractPaletteInternal(
    String trimmed,
    String normUrl,
  ) async {
    if (kIsWeb) {
      final int hash = trimmed.codeUnits.fold<int>(
        0,
        (acc, c) => (acc * 31 + c) & 0x7fffffff,
      );
      final double hue = (hash % 360).toDouble();
      final dominant = HSLColor.fromAHSL(1.0, hue, 0.62, 0.36).toColor();
      final vibrant =
          HSLColor.fromAHSL(1.0, (hue + 18) % 360, 0.78, 0.52).toColor();
      final muted = HSLColor.fromAHSL(1.0, hue, 0.38, 0.28).toColor();
      final darkMuted = HSLColor.fromAHSL(1.0, hue, 0.42, 0.14).toColor();
      final webPalette = ImmersivePalette.fromExtracted(
        dominant: dominant,
        vibrant: vibrant,
        muted: muted,
        darkMuted: darkMuted,
      );
      _storeInCache(trimmed, normUrl, webPalette);
      return webPalette;
    }

    try {
      ImageProvider baseProvider;
      if (trimmed.startsWith('file://') ||
          trimmed.startsWith('http://local.image/')) {
        final path = trimmed
            .replaceFirst('file://', '')
            .replaceFirst('http://local.image/', '');
        final file = File(path);
        if (file.existsSync()) {
          baseProvider = FileImage(file);
        } else {
          return ImmersivePalette.fallback;
        }
      } else if (trimmed.startsWith('http://') ||
          trimmed.startsWith('https://')) {
        baseProvider = CachedNetworkImageProvider(normUrl);
      } else {
        return ImmersivePalette.fallback;
      }

      // Échantillonnage 32x32 (2,2x moins de pixels que 48x48 pour un résultat identique)
      final resized = ResizeImage(baseProvider, width: 32, height: 32);
      final gen = await PaletteGenerator.fromImageProvider(
        resized,
        maximumColorCount: 12,
      );

      final extracted = ImmersivePalette.fromExtracted(
        dominant: gen.dominantColor?.color,
        vibrant: gen.vibrantColor?.color,
        lightVibrant: gen.lightVibrantColor?.color,
        darkVibrant: gen.darkVibrantColor?.color,
        muted: gen.mutedColor?.color,
        darkMuted: gen.darkMutedColor?.color,
      );

      _storeInCache(trimmed, normUrl, extracted);
      return extracted;
    } catch (_) {
      return ImmersivePalette.fallback;
    }
  }
}
