import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;

import '../../../../../core/audio/audio_device_service.dart';
import '../../../../../core/theme/app_animations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/artist_name_display.dart';
import '../../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../../offline/presentation/cubit/download_cubit.dart';
import '../../../data/models/track_model.dart';
import 'player_favorite_button.dart';

/// Palette harmonisée extraite de la pochette pour les modes immersifs.
/// Les niveaux de luminosité et de saturation sont bornés afin de garantir :
/// 1) une fusion naturelle avec le bas de la pochette,
/// 2) un contraste parfait des textes et contrôles blancs (même sur pochette blanche).
@immutable
class ImmersivePalette {
  final Color midColor;
  final Color deepColor;
  final Color accentColor;
  final Color dominantColor;

  const ImmersivePalette({
    required this.midColor,
    required this.deepColor,
    required this.accentColor,
    this.dominantColor = const Color(0xFFFA7921),
  });

  static const ImmersivePalette fallback = ImmersivePalette(
    midColor: Color(0xFF232B2E),
    deepColor: Color(0xFF111619),
    accentColor: Color(0xFFFFB74D),
    dominantColor: Color(0xFFFA7921),
  );

  /// Teinte riche et lisible issue de la couleur dominante de la pochette
  /// pour habiller la barre de titre des cartes sans nuire au contraste du texte blanc.
  Color get cardBarColor {
    final hsl = HSLColor.fromColor(dominantColor);
    if (hsl.saturation < 0.08) {
      return const Color(0xFF24242C);
    }
    return hsl
        .withSaturation(hsl.saturation.clamp(0.35, 0.78))
        .withLightness(hsl.lightness.clamp(0.22, 0.34))
        .toColor();
  }

  static Color _pickMostStrikingColor({
    Color? dominant,
    Color? vibrant,
    Color? lightVibrant,
    Color? darkVibrant,
    Color? muted,
    Color? darkMuted,
  }) {
    final candidates = <MapEntry<Color, double>>[
      if (vibrant != null) MapEntry(vibrant, 1.35),
      if (dominant != null) MapEntry(dominant, 1.18),
      if (lightVibrant != null) MapEntry(lightVibrant, 1.12),
      if (darkVibrant != null) MapEntry(darkVibrant, 1.08),
      if (muted != null) MapEntry(muted, 0.72),
      if (darkMuted != null) MapEntry(darkMuted, 0.58),
    ];
    if (candidates.isEmpty) return const Color(0xFF232B2E);

    Color best = candidates.first.key;
    double bestScore = -1.0;

    for (final entry in candidates) {
      final hsl = HSLColor.fromColor(entry.key);
      // Pénaliser fortement les couleurs quasi achromatiques (noir, blanc, gris)
      // ou ultra-sombres/ultra-délavées pour privilégier la teinte marquante.
      final double lumWeight = (hsl.lightness >= 0.14 && hsl.lightness <= 0.84)
          ? 1.0
          : (hsl.lightness < 0.14 ? 0.32 : 0.45);
      final double satScore = hsl.saturation < 0.08
          ? hsl.saturation * 0.25
          : (0.25 + hsl.saturation * 1.45);
      final double score = satScore * lumWeight * entry.value;
      if (score > bestScore) {
        bestScore = score;
        best = entry.key;
      }
    }
    return best;
  }

  factory ImmersivePalette.fromExtracted({
    Color? dominant,
    Color? vibrant,
    Color? lightVibrant,
    Color? darkVibrant,
    Color? muted,
    Color? darkMuted,
  }) {
    final Color striking = _pickMostStrikingColor(
      dominant: dominant,
      vibrant: vibrant,
      lightVibrant: lightVibrant,
      darkVibrant: darkVibrant,
      muted: muted,
      darkMuted: darkMuted,
    );
    final hsl = HSLColor.fromColor(striking);

    final bool isMonochrome = hsl.saturation < 0.08;
    final double midSat = isMonochrome ? 0.04 : hsl.saturation.clamp(0.38, 0.82);
    final double midLight = isMonochrome
        ? hsl.lightness.clamp(0.18, 0.28)
        : hsl.lightness.clamp(0.24, 0.38);
    final Color mid = hsl
        .withSaturation(midSat)
        .withLightness(midLight)
        .toColor();

    // Base profonde dérivée de la couleur marquante (ou darkVibrant si saturé)
    // pour éviter qu'un darkMuted grisâtre n'éteigne la lueur colorée.
    HSLColor deepBase = hsl.withHue((hsl.hue + 4.0) % 360.0);
    if (darkVibrant != null) {
      final dv = HSLColor.fromColor(darkVibrant);
      if (dv.saturation >= 0.30) deepBase = dv;
    } else if (darkMuted != null && isMonochrome) {
      deepBase = HSLColor.fromColor(darkMuted);
    }
    final double deepSat = isMonochrome
        ? 0.04
        : deepBase.saturation.clamp(0.30, 0.72);
    final double deepLight = deepBase.lightness.clamp(0.11, 0.19);
    final Color deep = deepBase
        .withSaturation(deepSat)
        .withLightness(deepLight)
        .toColor();

    final HSLColor accentHsl = HSLColor.fromColor(
      vibrant ?? lightVibrant ?? striking,
    );
    final Color accent = accentHsl
        .withSaturation(isMonochrome ? 0.0 : accentHsl.saturation.clamp(0.55, 0.94))
        .withLightness(accentHsl.lightness.clamp(0.60, 0.78))
        .toColor();

    final Color resolvedDominant = hsl
        .withSaturation(isMonochrome ? 0.06 : hsl.saturation.clamp(0.46, 0.94))
        .withLightness(hsl.lightness.clamp(0.40, 0.58))
        .toColor();

    return ImmersivePalette(
      midColor: mid,
      deepColor: deep,
      accentColor: accent,
      dominantColor: resolvedDominant,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImmersivePalette &&
          midColor == other.midColor &&
          deepColor == other.deepColor &&
          accentColor == other.accentColor &&
          dominantColor == other.dominantColor;

  @override
  int get hashCode =>
      Object.hash(midColor, deepColor, accentColor, dominantColor);
}

/// Couche atmosphérique plein écran mise en cache GPU via [RepaintBoundary].
/// Combine la miniature ultra-légère (120 px max en VRAM) floutée une seule fois
/// par morceau avec le dégradé chromatique [ImmersivePalette] pour conserver
/// les teintes spatiales gauche/droite du bas de la pochette sans coût GPU continu.
class ImmersiveAtmosphereBackground extends StatelessWidget {
  final String coverUrl;
  final ImmersivePalette palette;

  const ImmersiveAtmosphereBackground({
    super.key,
    required this.coverUrl,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final Color midBlend = Color.lerp(palette.midColor, palette.deepColor, 0.52)!;

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: AppAnimations.slow,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.58, 1.0],
            colors: [
              palette.midColor,
              midBlend,
              palette.deepColor,
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (coverUrl.isNotEmpty)
              AnimatedSwitcher(
                duration: AppAnimations.slow,
                child: SizedBox.expand(
                  key: ValueKey('immersive_bg_$coverUrl'),
                  child: ClipRect(
                    child: Opacity(
                      opacity: 0.54,
                      child: Transform.scale(
                        scale: 1.22,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: 26,
                            sigmaY: 26,
                            tileMode: TileMode.clamp,
                          ),
                          child: SonoritizArtwork(
                            imageUrl: coverUrl,
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: 0,
                            fit: BoxFit.cover,
                            alignment: Alignment.bottomCenter,
                            cacheMaxDimension: 120,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Halo radial issu de la couleur la plus marquante de la pochette
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.35),
                    radius: 1.15,
                    colors: [
                      palette.dominantColor.withValues(alpha: 0.34),
                      palette.midColor.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            // Voile d'harmonisation garantissant la continuité chromatique et la lisibilité
            AnimatedContainer(
              duration: AppAnimations.slow,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.45, 0.68, 1.0],
                  colors: [
                    palette.dominantColor.withValues(alpha: 0.16),
                    palette.midColor.withValues(alpha: 0.36),
                    midBlend.withValues(alpha: 0.72),
                    palette.deepColor.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Masque de fusion en courbe en S (cosinus) sans bande de Mach :
/// dissout progressivement le bas de la pochette plein écran dans l'atmosphère.
class ImmersiveMeltingCoverMask extends StatelessWidget {
  final Widget child;

  const ImmersiveMeltingCoverMask({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.44, 0.56, 0.68, 0.80, 0.91, 1.0],
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              Color(0xE0FFFFFF),
              Color(0x9EFFFFFF),
              Color(0x4DFFFFFF),
              Color(0x14FFFFFF),
              Color(0x00FFFFFF),
            ],
          ).createShader(bounds);
        },
        child: child,
      ),
    );
  }
}

/// Bouton rond translucide sans BackdropFilter (0 passe GPU offscreen).
class ImmersiveGlassCircleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;
  final bool isHighlighted;

  const ImmersiveGlassCircleButton({
    super.key,
    required this.child,
    required this.onTap,
    this.tooltip,
    this.size = 38,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isHighlighted
              ? AppColors.primary.withValues(alpha: 0.88)
              : Colors.black.withValues(alpha: 0.32),
          border: Border.all(
            color: isHighlighted
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.16),
            width: 0.9,
          ),
        ),
        child: Center(child: child),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// ============================================================================
/// COMPOSANTS DU 3E LECTEUR : « HALO ORBITAL » (100 % ORIGINAL SONORITIZ)
/// ============================================================================

/// 1. Rail vertical flottant à gauche dans la zone de brume de la pochette :
/// regroupe Favori/Superlike • Paroles • File d'attente.
class ImmersiveFloatingSideRail extends StatelessWidget {
  final TrackModel track;
  final VoidCallback onLyricsTapped;
  final VoidCallback onQueueTapped;
  final VoidCallback? onKaraokeTapped;

  const ImmersiveFloatingSideRail({
    super.key,
    required this.track,
    required this.onLyricsTapped,
    required this.onQueueTapped,
    this.onKaraokeTapped,
  });

  Widget _horizontalHairline() {
    return Container(
      width: 18,
      height: 1,
      color: Colors.white.withValues(alpha: 0.14),
    );
  }

  Widget _railAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 42,
          height: 40,
          child: Center(
            child: Icon(
              icon,
              size: 19,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerFavoriteButton(
            track: track,
            size: 40,
            iconSize: 20,
          ),
          _horizontalHairline(),
          _railAction(
            icon: Icons.lyrics_outlined,
            tooltip: 'Paroles',
            onTap: onLyricsTapped,
          ),
          if (onKaraokeTapped != null) ...[
            _horizontalHairline(),
            _railAction(
              icon: Icons.mic_external_on_rounded,
              tooltip: 'Mode Karaoké',
              onTap: onKaraokeTapped!,
            ),
          ],
          _horizontalHairline(),
          _railAction(
            icon: Icons.queue_music_rounded,
            tooltip: 'File d\'attente',
            onTap: onQueueTapped,
          ),
        ],
      ),
    );
  }
}

/// 2. Scène typographique « Affiche Cinéma » centrée dans la brume colorée.
class ImmersiveCinemaTitleStage extends StatelessWidget {
  final TrackModel track;
  final Duration position;
  final Duration duration;
  final ImmersivePalette palette;

  const ImmersiveCinemaTitleStage({
    super.key,
    required this.track,
    required this.position,
    required this.duration,
    required this.palette,
  });

  String _formatDuration(Duration d) {
    final totalSec = d.inSeconds.clamp(0, 359999);
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23.0,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.18,
              shadows: [
                Shadow(
                  color: Color(0x70000000),
                  blurRadius: 14,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: ArtistNameDisplay(
                  artistName: track.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 15.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    shadows: const [
                      Shadow(
                        color: Color(0x55000000),
                        blurRadius: 10,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Pilule temporelle tabulaire fine sous l'artiste
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3.5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 3. Cadran central « Halo Orbital » :
/// Anneau de progression circulaire tactile à 360° autour du bouton Play/Pause,
/// encadré de deux ailes sculptées [Mix • Précédent] et [Suivant • Boucle].
class ImmersiveOrbitalControlHub extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isBuffering;
  final bool isSuperliked;
  final bool isShuffleModeEnabled;
  final LoopMode loopMode;
  final ImmersivePalette palette;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;
  final ValueChanged<Duration> onSeek;

  const ImmersiveOrbitalControlHub({
    super.key,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.isBuffering,
    required this.isSuperliked,
    required this.isShuffleModeEnabled,
    required this.loopMode,
    required this.palette,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
    required this.onSeek,
  });

  @override
  State<ImmersiveOrbitalControlHub> createState() =>
      _ImmersiveOrbitalControlHubState();
}

class _ImmersiveOrbitalControlHubState
    extends State<ImmersiveOrbitalControlHub> {
  static const double _dialSize = 104.0;
  static const double _innerPlaySize = 62.0;

  double? _dragFraction;
  int _lastHapticStep = -1;

  double _effectiveFraction() {
    if (_dragFraction != null) return _dragFraction!.clamp(0.0, 1.0);
    final totalMs = widget.duration.inMilliseconds;
    if (totalMs <= 0) return 0.0;
    return (widget.position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  /// Convertit un point local `(dx, dy)` sur le cadran en fraction horaire [0..1] depuis 12h.
  double _offsetToClockwiseFraction(Offset localPos, {double? previous}) {
    const double center = _dialSize / 2;
    final double dx = localPos.dx - center;
    final double dy = localPos.dy - center;
    double angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    double raw = (angle / (2 * math.pi)).clamp(0.0, 1.0);

    // Protection anti-saut à 12h (évite de passer brutalement de 99 % à 0 % en glissant)
    if (previous != null && (raw - previous).abs() > 0.5) {
      raw = previous > 0.5 ? 1.0 : 0.0;
    }
    return raw;
  }

  bool _isOnOrbitalRing(Offset localPos) {
    const double center = _dialSize / 2;
    final double dist = (localPos - const Offset(center, center)).distance;
    return dist >= (_innerPlaySize / 2 - 2.0);
  }

  String _formatDuration(Duration d) {
    final totalSec = d.inSeconds.clamp(0, 359999);
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildWingCapsule({required List<Widget> children}) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 0.9,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildWingModeButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 40,
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.65),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: isActive ? 4.5 : 0,
                height: isActive ? 4.5 : 0,
                decoration: BoxDecoration(
                  color: widget.palette.accentColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWingSkipButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(
              icon,
              size: 29,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double fraction = _effectiveFraction();
    final bool isDragging = _dragFraction != null;
    final bool isRepeatActive = widget.loopMode != LoopMode.off;
    final int totalMs = widget.duration.inMilliseconds;
    final Duration previewPos = Duration(
      milliseconds: (fraction * totalMs).round(),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Aile gauche : [Mix • Précédent]
          _buildWingCapsule(
            children: [
              _buildWingModeButton(
                icon: Icons.shuffle_rounded,
                tooltip: 'Aléatoire',
                isActive: widget.isShuffleModeEnabled,
                onTap: widget.onShuffle,
              ),
              const SizedBox(width: 2),
              _buildWingSkipButton(
                icon: Icons.skip_previous_rounded,
                tooltip: 'Précédent',
                onTap: widget.onPrevious,
              ),
            ],
          ),

          const SizedBox(width: 14),

          // Cadran central « Halo Orbital » (Anneau 360° + Bouton Play blanc)
          SizedBox(
            width: _dialSize,
            height: _dialSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Bulle d'aperçu temporel au-dessus de l'anneau pendant le scrubbing rotatif
                if (isDragging)
                  Positioned(
                    top: -34,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xEE101316),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.palette.accentColor.withValues(alpha: 0.78),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        _formatDuration(previewPos),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),

                // Couche tactile & graphique de l'anneau orbital (isolée par RepaintBoundary)
                RepaintBoundary(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      if (!_isOnOrbitalRing(details.localPosition)) return;
                      HapticFeedback.selectionClick();
                      final f = _offsetToClockwiseFraction(
                        details.localPosition,
                      );
                      widget.onSeek(
                        Duration(milliseconds: (f * totalMs).round()),
                      );
                    },
                    onPanStart: (details) {
                      if (!_isOnOrbitalRing(details.localPosition)) return;
                      HapticFeedback.selectionClick();
                      final f = _offsetToClockwiseFraction(
                        details.localPosition,
                      );
                      _lastHapticStep = (f * 20).floor();
                      setState(() => _dragFraction = f);
                    },
                    onPanUpdate: (details) {
                      if (_dragFraction == null) return;
                      final f = _offsetToClockwiseFraction(
                        details.localPosition,
                        previous: _dragFraction,
                      );
                      final step = (f * 20).floor();
                      if (step != _lastHapticStep) {
                        _lastHapticStep = step;
                        HapticFeedback.selectionClick();
                      }
                      setState(() => _dragFraction = f);
                    },
                    onPanEnd: (_) {
                      if (_dragFraction != null) {
                        final targetMs = (_dragFraction! * totalMs).round();
                        widget.onSeek(Duration(milliseconds: targetMs));
                        setState(() => _dragFraction = null);
                      }
                    },
                    onPanCancel: () {
                      if (_dragFraction != null) {
                        setState(() => _dragFraction = null);
                      }
                    },
                    child: CustomPaint(
                      size: const Size(_dialSize, _dialSize),
                      painter: _OrbitalHaloPainter(
                        fraction: fraction,
                        isDragging: isDragging,
                        isSuperliked: widget.isSuperliked,
                        accentColor: widget.palette.accentColor,
                      ),
                    ),
                  ),
                ),

                // Cœur Play / Pause blanc pur (cible prioritaire au centre)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onPlayPause();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: _innerPlaySize,
                    height: _innerPlaySize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.30),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.isBuffering
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: RepaintBoundary(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: widget.palette.deepColor,
                                ),
                              ),
                            )
                          : Icon(
                              widget.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 34,
                              color: const Color(0xFF101316),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Aile droite : [Suivant • Boucle]
          _buildWingCapsule(
            children: [
              _buildWingSkipButton(
                icon: Icons.skip_next_rounded,
                tooltip: 'Suivant',
                onTap: widget.onNext,
              ),
              const SizedBox(width: 2),
              _buildWingModeButton(
                icon: widget.loopMode == LoopMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                tooltip: 'Répéter',
                isActive: isRepeatActive,
                onTap: widget.onRepeat,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrbitalHaloPainter extends CustomPainter {
  final double fraction;
  final bool isDragging;
  final bool isSuperliked;
  final Color accentColor;

  _OrbitalHaloPainter({
    required this.fraction,
    required this.isDragging,
    required this.isSuperliked,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 8.5;
    final double strokeWidth = isDragging ? 6.2 : 4.4;
    final Rect arcRect = Rect.fromCircle(center: center, radius: radius);

    // 1. Anneau de piste inactif
    final Paint trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Arc de progression actif depuis 12h (-pi/2)
    final double clamped = fraction.clamp(0.0, 1.0);
    if (clamped > 0.002) {
      final double sweepAngle = 2 * math.pi * clamped;
      final Paint activePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isSuperliked
              ? const [
                  Color(0xFFFFEA00),
                  Color(0xFFFF6D00),
                  Color(0xFFFF1744),
                ]
              : [
                  Colors.white,
                  accentColor,
                ],
        ).createShader(arcRect);

      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        sweepAngle,
        false,
        activePaint,
      );
    }

    // 3. Satellite lumineux sur la tête de lecture orbitale
    final double headAngle = -math.pi / 2 + (2 * math.pi * clamped);
    final Offset headOffset = Offset(
      center.dx + radius * math.cos(headAngle),
      center.dy + radius * math.sin(headAngle),
    );
    final double dotRadius = isDragging ? 6.8 : 5.0;

    canvas.drawCircle(
      headOffset,
      dotRadius + 3.0,
      Paint()
        ..color = (isSuperliked ? const Color(0xFFFF6D00) : accentColor)
            .withValues(alpha: isDragging ? 0.45 : 0.28),
    );
    canvas.drawCircle(
      headOffset,
      dotRadius,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitalHaloPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.isSuperliked != isSuperliked ||
        oldDelegate.accentColor != accentColor;
  }
}

/// 4. Pastille compacte centrée en bas : Sortie Audio + Sauvegarde Hors-ligne.
class ImmersiveCompactDevicePill extends StatelessWidget {
  final TrackModel currentTrack;
  final VoidCallback onDownloadFeedback;

  const ImmersiveCompactDevicePill({
    super.key,
    required this.currentTrack,
    required this.onDownloadFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final deviceService = AudioDeviceService();

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<AudioOutputDevice>(
            stream: deviceService.deviceStream,
            initialData: deviceService.currentDevice,
            builder: (context, snapshot) {
              final device = snapshot.data ?? deviceService.currentDevice;
              return GestureDetector(
                onTap: () => deviceService.openOutputSwitcher(),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      device.icon,
                      size: 15,
                      color: device.isExternal
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text(
                        device.isExternal ? device.name : 'Sortie audio',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: device.isExternal
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.82),
                          fontSize: 11.5,
                          fontWeight:
                              device.isExternal ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              width: 1,
              height: 13,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          BlocBuilder<DownloadCubit, DownloadState>(
            builder: (context, downloadState) {
              bool isDownloaded = false;
              bool isDownloading = false;
              if (downloadState is DownloadStateData) {
                isDownloaded =
                    downloadState.downloadedIds.contains(currentTrack.id);
                isDownloading = downloadState.downloadingProgress
                    .containsKey(currentTrack.id);
              }
              return GestureDetector(
                onTap: () {
                  if (currentTrack.id.startsWith('local_') || isDownloading) {
                    return;
                  }
                  if (isDownloaded) {
                    context
                        .read<DownloadCubit>()
                        .removeDownload(currentTrack.id);
                  } else {
                    context.read<DownloadCubit>().downloadTrack(currentTrack);
                  }
                  onDownloadFeedback();
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDownloading)
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: RepaintBoundary(
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      Icon(
                        isDownloaded
                            ? Icons.download_done_rounded
                            : Icons.download_outlined,
                        size: 15,
                        color: isDownloaded
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.85),
                      ),
                    const SizedBox(width: 5),
                    Text(
                      isDownloading
                          ? '...'
                          : (isDownloaded ? 'Hors-ligne' : 'Sauver'),
                      style: TextStyle(
                        color: isDownloaded
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.82),
                        fontSize: 11.5,
                        fontWeight:
                            isDownloaded ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// BANNIÈRE « À SUIVRE » (UP NEXT TEASER) POUR LES 4 LECTEURS
/// - Apparaît de la gauche vers la droite à 30 secondes de la fin du morceau.
/// - Reste affichée pendant 7 secondes (de -30s à -23s), puis repart à gauche.
/// - Cliquable pour passer immédiatement au morceau suivant.
/// ============================================================================
class SonoritizUpNextTeaserBanner extends StatefulWidget {
  final String currentTrackId;
  final TrackModel? nextTrack;
  final Duration position;
  final Duration duration;
  final Color accentColor;
  final VoidCallback onTapNext;

  const SonoritizUpNextTeaserBanner({
    super.key,
    required this.currentTrackId,
    required this.nextTrack,
    required this.position,
    required this.duration,
    required this.accentColor,
    required this.onTapNext,
  });

  @override
  State<SonoritizUpNextTeaserBanner> createState() =>
      _SonoritizUpNextTeaserBannerState();
}

class _SonoritizUpNextTeaserBannerState
    extends State<SonoritizUpNextTeaserBanner> {
  String? _dismissedForTrackId;

  @override
  Widget build(BuildContext context) {
    final next = widget.nextTrack;
    final int totalSec = widget.duration.inSeconds;
    final int posSec = widget.position.inSeconds;
    final int remainingSec = totalSec - posSec;

    // Apparaît à 30s de la fin et disparaît après 7 secondes (à 23s de la fin)
    final bool inTimeWindow =
        totalSec >= 40 && remainingSec <= 30 && remainingSec >= 23;
    final bool isDismissed = _dismissedForTrackId == widget.currentTrackId;
    final bool showBanner = next != null && inTimeWindow && !isDismissed;

    return IgnorePointer(
      ignoring: !showBanner,
      child: RepaintBoundary(
        child: AnimatedSlide(
          offset: showBanner ? Offset.zero : const Offset(-1.18, 0.0),
          duration: const Duration(milliseconds: 440),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: showBanner ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            child: next == null
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onTapNext();
                    },
                    onHorizontalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) < -120) {
                        setState(() {
                          _dismissedForTrackId = widget.currentTrackId;
                        });
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 236),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.74),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: widget.accentColor.withValues(alpha: 0.55),
                            width: 1.15,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.42),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              color: widget.accentColor.withValues(alpha: 0.20),
                              blurRadius: 14,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SonoritizArtwork(
                              imageUrl: next.coverUrl,
                              width: 44,
                              height: 44,
                              borderRadius: 10,
                              fit: BoxFit.cover,
                              cacheMaxDimension: 140,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 5.5,
                                        height: 5.5,
                                        decoration: BoxDecoration(
                                          color: widget.accentColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          'À SUIVRE',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: widget.accentColor,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.9,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Icon(
                                        Icons.skip_next_rounded,
                                        size: 13,
                                        color: widget.accentColor,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    next.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    next.artistName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.76),
                                      fontSize: 11.2,
                                      fontWeight: FontWeight.w600,
                                      height: 1.15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
