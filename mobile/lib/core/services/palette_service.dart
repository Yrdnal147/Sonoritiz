import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
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
