import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../home/domain/recommendation_engine.dart';
import '../../../player/presentation/widgets/player_components/immersive_player_widgets.dart';

/// Affiche le nom d'un artiste avec une identité visuelle personnalisée
/// et un soulignement centré au milieu :
/// - Souligné en Orange (`AppColors.primary`) par défaut.
/// - Si la photo de profil de l'artiste est proche de cet Orange, bascule
///   automatiquement en Blanc ou en Noir en fonction de la luminosité de la photo.
class ArtistPersonalizedWordmark extends StatefulWidget {
  final String artistName;
  final Color accentColor;
  final Color underlineColor;
  final double maxHeight;
  final double maxWidth;

  const ArtistPersonalizedWordmark({
    super.key,
    required this.artistName,
    required this.accentColor,
    this.underlineColor = AppColors.primary,
    this.maxHeight = 72,
    this.maxWidth = 290,
  });

  /// Détermine si une couleur est proche de l'Orange primaire Sonoritiz (#FA7921).
  static bool isCloseToPrimaryOrange(Color color) {
    final hsl = HSLColor.fromColor(color);
    final bool hueInOrangeBand = hsl.hue >= 6.0 && hsl.hue <= 48.0;
    final bool hasWarmSaturation = hsl.saturation >= 0.28;
    final bool hasVisibleLightness =
        hsl.lightness >= 0.16 && hsl.lightness <= 0.85;
    if (hueInOrangeBand && hasWarmSaturation && hasVisibleLightness) {
      return true;
    }

    final int dr = (color.r * 255.0).round() - 250;
    final int dg = (color.g * 255.0).round() - 121;
    final int db = (color.b * 255.0).round() - 33;
    final int distSq = (dr * dr) + (dg * dg) + (db * db);
    return distSq <= (105 * 105);
  }

  /// Règle chromatique unifiée pour le soulignement du nom et le background des 3 boutons :
  /// - Par défaut : Orange primaire (`AppColors.primary`).
  /// - Si la photo de l'artiste est proche de cet Orange : Blanc ou Noir selon la pochette.
  static Color resolveAdaptivePrimaryColor(ImmersivePalette palette) {
    final bool nearOrange = isCloseToPrimaryOrange(palette.dominantColor) ||
        isCloseToPrimaryOrange(palette.accentColor) ||
        isCloseToPrimaryOrange(palette.midColor);

    if (!nearOrange) {
      return AppColors.primary;
    }

    // Si la pochette est claire -> Noir ; sinon -> Blanc pour un contraste optimal
    final double lum = palette.dominantColor.computeLuminance();
    return lum >= 0.42 ? Colors.black : Colors.white;
  }

  /// Couleur d'icône/texte contrastée sur le background adaptatif (Orange / Blanc / Noir).
  static Color resolveForegroundOn(Color background) {
    if (background == Colors.black) return Colors.white;
    if (background == Colors.white) return Colors.black;
    return ThemeData.estimateBrightnessForColor(background) == Brightness.light
        ? Colors.black
        : Colors.white;
  }

  /// Calcule une teinte pastel/lumineuse haute lisibilité à partir de la couleur
  /// dominante de la photo de l'artiste (pour le texte ou les halos).
  static Color luminousTintFrom(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    if (hsl.saturation < 0.08) {
      return const Color(0xFFF6F7FA);
    }
    return hsl
        .withSaturation(hsl.saturation.clamp(0.55, 0.88))
        .withLightness(hsl.lightness.clamp(0.76, 0.88))
        .toColor();
  }

  @override
  State<ArtistPersonalizedWordmark> createState() =>
      _ArtistPersonalizedWordmarkState();
}

class _ArtistPersonalizedWordmarkState
    extends State<ArtistPersonalizedWordmark> {
  static final Map<String, String?> _logoCache = <String, String?>{};
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ),
  );

  String? _officialLogoUrl;
  bool _logoFailed = false;

  @override
  void initState() {
    super.initState();
    _loadOfficialLogo();
  }

  @override
  void didUpdateWidget(covariant ArtistPersonalizedWordmark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistName != widget.artistName) {
      _officialLogoUrl = null;
      _logoFailed = false;
      _loadOfficialLogo();
    }
  }

  static String _normalizeName(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _loadOfficialLogo() async {
    final cleanName = widget.artistName.trim();
    if (cleanName.isEmpty || cleanName.toLowerCase() == 'artiste inconnu') {
      return;
    }

    final cacheKey = _normalizeName(cleanName);
    if (_logoCache.containsKey(cacheKey)) {
      final cached = _logoCache[cacheKey];
      if (cached != null && mounted) {
        setState(() => _officialLogoUrl = cached);
      }
      return;
    }

    try {
      final url =
          'https://www.theaudiodb.com/api/v1/json/2/search.php?s=${Uri.encodeComponent(cleanName)}';
      final response = await _dio.get(url);
      final data = response.data;
      if (data is Map && data['artists'] is List) {
        final artists = data['artists'] as List;
        String? matchedLogo;
        for (final raw in artists) {
          if (raw is! Map) continue;
          final apiName = (raw['strArtist'] ?? '').toString();
          final altName = (raw['strArtistAlternate'] ?? '').toString();
          final logo = (raw['strArtistLogo'] ?? '').toString().trim();
          if (logo.isEmpty ||
              (!logo.startsWith('http://') && !logo.startsWith('https://'))) {
            continue;
          }
          final normApi = _normalizeName(apiName);
          final normAlt = _normalizeName(altName);
          if (normApi == cacheKey ||
              (normAlt.isNotEmpty && normAlt == cacheKey)) {
            matchedLogo = logo;
            break;
          }
        }
        _logoCache[cacheKey] = matchedLogo;
        if (matchedLogo != null && mounted) {
          setState(() => _officialLogoUrl = matchedLogo);
        }
      } else {
        _logoCache[cacheKey] = null;
      }
    } catch (_) {
      // Silencieux : en cas d'absence de réseau ou de blocage CORS sur Web,
      // on conserve la typographie personnalisée déjà affichée instantanément.
      _logoCache[cacheKey] = null;
    }
  }

  int _deterministicHash(String value) {
    int hash = 5381;
    for (final unit in value.toLowerCase().trim().codeUnits) {
      hash = ((hash << 5) + hash + unit) & 0x7fffffff;
    }
    return hash;
  }

  _WordmarkSpec _resolveTypographySpec(String name) {
    final family = RecommendationEngine.classifyArtist(name);
    final hash = _deterministicHash(name);
    final int len = name.trim().length;

    // Taille de base adaptée à la longueur du nom pour éviter les coupures disgracieuses.
    final double baseSize = len <= 8
        ? 44
        : len <= 13
            ? 38
            : len <= 19
                ? 33
                : 28;

    final Color textColor =
        ArtistPersonalizedWordmark.luminousTintFrom(widget.accentColor);
    final List<Shadow> shadows = [
      Shadow(
        color: widget.accentColor.withValues(alpha: 0.42),
        blurRadius: 22,
      ),
      Shadow(
        color: Colors.black.withValues(alpha: 0.72),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ];

    TextStyle applyBase(
      TextStyle style, {
      double scale = 1.0,
      double letterSpacing = 0.0,
      FontWeight? weight,
      FontStyle? fontStyle,
    }) {
      return style.copyWith(
        fontSize: (baseSize * scale).clamp(24.0, 52.0),
        color: textColor,
        letterSpacing: letterSpacing,
        fontWeight: weight,
        fontStyle: fontStyle,
        height: 1.04,
        shadows: shadows,
      );
    }

    switch (family) {
      case TasteFamily.rnb:
        final variant = hash % 3;
        if (variant == 0) {
          return _WordmarkSpec(
            displayText: name,
            style: applyBase(
              GoogleFonts.dancingScript(),
              scale: 1.18,
              letterSpacing: 0.5,
              weight: FontWeight.w700,
            ),
          );
        } else if (variant == 1) {
          return _WordmarkSpec(
            displayText: name,
            style: applyBase(
              GoogleFonts.playfairDisplay(),
              scale: 1.0,
              letterSpacing: -0.4,
              weight: FontWeight.w700,
              fontStyle: FontStyle.italic,
            ),
          );
        } else {
          return _WordmarkSpec(
            displayText: name,
            style: applyBase(
              GoogleFonts.satisfy(),
              scale: 1.12,
              letterSpacing: 0.4,
              weight: FontWeight.w400,
            ),
          );
        }

      case TasteFamily.hipHop:
        final variant = hash % 3;
        if (variant == 0) {
          return _WordmarkSpec(
            displayText: name.toUpperCase(),
            style: applyBase(
              GoogleFonts.anton(),
              scale: 1.05,
              letterSpacing: 1.8,
              weight: FontWeight.w400,
            ),
          );
        } else if (variant == 1) {
          return _WordmarkSpec(
            displayText: name.toUpperCase(),
            style: applyBase(
              GoogleFonts.bebasNeue(),
              scale: 1.2,
              letterSpacing: 2.6,
              weight: FontWeight.w400,
            ),
          );
        } else {
          return _WordmarkSpec(
            displayText: name.toUpperCase(),
            style: applyBase(
              GoogleFonts.syne(),
              scale: 0.92,
              letterSpacing: 1.4,
              weight: FontWeight.w800,
            ),
          );
        }

      case TasteFamily.afro:
        final variant = hash % 3;
        if (variant == 0) {
          return _WordmarkSpec(
            displayText: name,
            style: applyBase(
              GoogleFonts.syne(),
              scale: 0.96,
              letterSpacing: -0.6,
              weight: FontWeight.w800,
            ),
          );
        } else if (variant == 1) {
          return _WordmarkSpec(
            displayText: name,
            style: applyBase(
              GoogleFonts.righteous(),
              scale: 1.0,
              letterSpacing: 0.8,
              weight: FontWeight.w400,
            ),
          );
        } else {
          return _WordmarkSpec(
            displayText: name.toUpperCase(),
            style: applyBase(
              GoogleFonts.unbounded(),
              scale: 0.84,
              letterSpacing: 1.0,
              weight: FontWeight.w700,
            ),
          );
        }

      case TasteFamily.electro:
        final variant = hash % 2;
        if (variant == 0) {
          return _WordmarkSpec(
            displayText: name.toUpperCase(),
            style: applyBase(
              GoogleFonts.orbitron(),
              scale: 0.88,
              letterSpacing: 2.4,
              weight: FontWeight.w800,
            ),
          );
        } else {
          return _WordmarkSpec(
            displayText: name.toUpperCase(),
            style: applyBase(
              GoogleFonts.chakraPetch(),
              scale: 0.98,
              letterSpacing: 2.0,
              weight: FontWeight.w700,
            ),
          );
        }

      case TasteFamily.classical:
        final variant = hash % 2;
        if (variant == 0) {
          return _WordmarkSpec(
            displayText: name.toUpperCase(),
            style: applyBase(
              GoogleFonts.cinzel(),
              scale: 0.92,
              letterSpacing: 2.2,
              weight: FontWeight.w700,
            ),
          );
        } else {
          return _WordmarkSpec(
            displayText: name,
            style: applyBase(
              GoogleFonts.cormorantGaramond(),
              scale: 1.14,
              letterSpacing: 0.4,
              weight: FontWeight.w700,
              fontStyle: FontStyle.italic,
            ),
          );
        }

      case TasteFamily.chanson:
      case TasteFamily.jazzSoul:
        final variant = hash % 2;
        if (variant == 0) {
          return _WordmarkSpec(
            displayText: name,
            style: applyBase(
              GoogleFonts.playfairDisplay(),
              scale: 1.02,
              letterSpacing: -0.3,
              weight: FontWeight.w800,
            ),
          );
        } else {
          return _WordmarkSpec(
            displayText: name,
            style: applyBase(
              GoogleFonts.abrilFatface(),
              scale: 1.0,
              letterSpacing: 0.3,
              weight: FontWeight.w400,
            ),
          );
        }

      case TasteFamily.latinWorld:
        final variant = hash % 2;
        if (variant == 0) {
          return _WordmarkSpec(
            displayText: name,
            style: applyBase(
              GoogleFonts.pacifico(),
              scale: 1.04,
              letterSpacing: 0.4,
              weight: FontWeight.w400,
            ),
          );
        } else {
          return _WordmarkSpec(
            displayText: name,
            style: applyBase(
              GoogleFonts.righteous(),
              scale: 1.0,
              letterSpacing: 0.8,
              weight: FontWeight.w400,
            ),
          );
        }

      case TasteFamily.popRock:
      case null:
        final variant = hash % 6;
        switch (variant) {
          case 0:
            return _WordmarkSpec(
              displayText: name.toUpperCase(),
              style: applyBase(
                GoogleFonts.montserrat(),
                scale: 0.9,
                letterSpacing: 3.2,
                weight: FontWeight.w800,
              ),
            );
          case 1:
            return _WordmarkSpec(
              displayText: name,
              style: applyBase(
                GoogleFonts.playfairDisplay(),
                scale: 1.04,
                letterSpacing: -0.4,
                weight: FontWeight.w800,
                fontStyle: FontStyle.italic,
              ),
            );
          case 2:
            return _WordmarkSpec(
              displayText: name.toUpperCase(),
              style: applyBase(
                GoogleFonts.bebasNeue(),
                scale: 1.2,
                letterSpacing: 2.8,
                weight: FontWeight.w400,
              ),
            );
          case 3:
            return _WordmarkSpec(
              displayText: name,
              style: applyBase(
                GoogleFonts.syne(),
                scale: 0.96,
                letterSpacing: -0.5,
                weight: FontWeight.w800,
              ),
            );
          case 4:
            return _WordmarkSpec(
              displayText: name.toUpperCase(),
              style: applyBase(
                GoogleFonts.cinzel(),
                scale: 0.9,
                letterSpacing: 2.4,
                weight: FontWeight.w700,
              ),
            );
          default:
            return _WordmarkSpec(
              displayText: name,
              style: applyBase(
                GoogleFonts.archivoBlack(),
                scale: 0.9,
                letterSpacing: -0.6,
                weight: FontWeight.w400,
              ),
            );
        }
    }
  }

  Widget _buildStylizedText() {
    final spec = _resolveTypographySpec(widget.artistName);
    return Text(
      spec.displayText,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: spec.style,
    );
  }

  Widget _buildOfficialLogo(String logoUrl) {
    final Widget imageWidget = kIsWeb
        ? Image.network(
            logoUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_logoFailed) {
                  setState(() => _logoFailed = true);
                }
              });
              return _buildStylizedText();
            },
          )
        : CachedNetworkImage(
            imageUrl: logoUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => _buildStylizedText(),
            errorWidget: (_, __, ___) => _buildStylizedText(),
          );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: widget.maxHeight,
        maxWidth: widget.maxWidth,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
              spreadRadius: -8,
            ),
          ],
        ),
        child: imageWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showLogo = _officialLogoUrl != null && !_logoFailed;
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: showLogo
                ? KeyedSubtree(
                    key: ValueKey('logo:${widget.artistName}'),
                    child: _buildOfficialLogo(_officialLogoUrl!),
                  )
                : KeyedSubtree(
                    key: ValueKey('text:${widget.artistName}'),
                    child: _buildStylizedText(),
                  ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.center,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                constraints: const BoxConstraints(minWidth: 44, maxWidth: 150),
                height: 3.5,
                decoration: BoxDecoration(
                  color: widget.underlineColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: widget.underlineColor.withValues(alpha: 0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordmarkSpec {
  final String displayText;
  final TextStyle style;

  const _WordmarkSpec({
    required this.displayText,
    required this.style,
  });
}
