import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../features/player/presentation/widgets/player_components/immersive_player_widgets.dart';

/// Service partagé d'extraction de palette chromatique pour les modes immersifs,
/// le lecteur plein écran et les formats Sonoritiz Shorts.
class PaletteService {
  static final Map<String, ImmersivePalette> _cache = <String, ImmersivePalette>{};

  /// Retourne immédiatement la palette mise en cache si déjà extraite.
  static ImmersivePalette? getCached(String coverUrl) {
    final trimmed = coverUrl.trim();
    if (trimmed.isEmpty) return null;
    return _cache[trimmed];
  }

  /// Récupère ou génère la palette immersive à partir d'une URL de pochette (avec cache LRU).
  static Future<ImmersivePalette> getPalette(String coverUrl) async {
    final trimmed = coverUrl.trim();
    if (trimmed.isEmpty) return ImmersivePalette.fallback;

    final cached = _cache[trimmed];
    if (cached != null) {
      return cached;
    }

    // Sur navigateur Web (kIsWeb), la lecture directe des pixels d'une image externe
    // déclenche un re-téléchargement CORS XHR par pochette et sature les connexions.
    // On génère instantanément une palette harmonieuse déterministe (0 ms).
    if (kIsWeb) {
      final int hash = trimmed.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);
      final double hue = (hash % 360).toDouble();
      final dominant = HSLColor.fromAHSL(1.0, hue, 0.62, 0.36).toColor();
      final vibrant = HSLColor.fromAHSL(1.0, (hue + 18) % 360, 0.78, 0.52).toColor();
      final muted = HSLColor.fromAHSL(1.0, hue, 0.38, 0.28).toColor();
      final darkMuted = HSLColor.fromAHSL(1.0, hue, 0.42, 0.14).toColor();
      final webPalette = ImmersivePalette.fromExtracted(
        dominant: dominant,
        vibrant: vibrant,
        muted: muted,
        darkMuted: darkMuted,
      );
      if (_cache.length >= 120) {
        _cache.remove(_cache.keys.first);
      }
      _cache[trimmed] = webPalette;
      return webPalette;
    }

    try {
      ImageProvider baseProvider;
      if (trimmed.startsWith('file://') || trimmed.startsWith('http://local.image/')) {
        final path = trimmed
            .replaceFirst('file://', '')
            .replaceFirst('http://local.image/', '');
        final file = File(path);
        if (file.existsSync()) {
          baseProvider = FileImage(file);
        } else {
          return ImmersivePalette.fallback;
        }
      } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        baseProvider = CachedNetworkImageProvider(trimmed);
      } else {
        return ImmersivePalette.fallback;
      }

      final resized = ResizeImage(baseProvider, width: 48, height: 48);
      final gen = await PaletteGenerator.fromImageProvider(
        resized,
        maximumColorCount: 16,
      );

      final extracted = ImmersivePalette.fromExtracted(
        dominant: gen.dominantColor?.color,
        vibrant: gen.vibrantColor?.color,
        lightVibrant: gen.lightVibrantColor?.color,
        darkVibrant: gen.darkVibrantColor?.color,
        muted: gen.mutedColor?.color,
        darkMuted: gen.darkMutedColor?.color,
      );

      if (_cache.length >= 120) {
        _cache.remove(_cache.keys.first);
      }
      _cache[trimmed] = extracted;
      return extracted;
    } catch (_) {
      return ImmersivePalette.fallback;
    }
  }
}
