import 'dart:collection';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/services/palette_service.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_animations.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../../core/widgets/sonoritiz_icon_button.dart';
import '../../../../core/widgets/artist_name_display.dart';
import '../cubit/player_cubit.dart';
import '../cubit/player_state.dart';
import '../screens/fullscreen_player_screen.dart';
import '../../data/models/track_model.dart';
import 'player_components/immersive_player_widgets.dart';
import 'player_components/player_favorite_button.dart';

class MiniPlayerWidget extends StatefulWidget {
  const MiniPlayerWidget({Key? key}) : super(key: key);

  @override
  State<MiniPlayerWidget> createState() => _MiniPlayerWidgetState();
}

class _MiniPlayerWidgetState extends State<MiniPlayerWidget> {
  static final LinkedHashMap<String, (Color, ImmersivePalette)> _miniPaletteCache =
      LinkedHashMap<String, (Color, ImmersivePalette)>();

  Color? _dominantColor;
  ImmersivePalette _immersivePalette = ImmersivePalette.fallback;
  String? _lastCoverUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final initialCover = context.read<PlayerCubit>().state.currentTrack?.coverUrl;
      if (initialCover != null && initialCover.isNotEmpty) {
        _extractDominantColor(initialCover);
      }
    });
  }

  void _extractDominantColor(String coverUrl) {
    final trimmed = coverUrl.trim();
    if (trimmed == _lastCoverUrl || trimmed.isEmpty) return;
    _lastCoverUrl = trimmed;

    final sharedCached = PaletteService.getCached(trimmed);
    if (sharedCached != null) {
      if (mounted) {
        setState(() {
          _dominantColor = sharedCached.dominantColor;
          _immersivePalette = sharedCached;
        });
      }
      return;
    }

    final cached = _miniPaletteCache.remove(trimmed);
    if (cached != null) {
      _miniPaletteCache[trimmed] = cached;
      if (mounted) {
        setState(() {
          _dominantColor = cached.$1;
          _immersivePalette = cached.$2;
        });
      }
      return;
    }

    PaletteService.getPalette(trimmed).then((immersive) {
      final dominant = immersive.dominantColor;
      if (_miniPaletteCache.length >= 40) {
        _miniPaletteCache.remove(_miniPaletteCache.keys.first);
      }
      _miniPaletteCache[trimmed] = (dominant, immersive);
      if (mounted && _lastCoverUrl == trimmed) {
        setState(() {
          _dominantColor = dominant;
          _immersivePalette = immersive;
        });
      }
    }).catchError((_) {});
  }

  void _openFullscreenPlayer(BuildContext context) {
    final playerCubit = context.read<PlayerCubit>();
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return BlocProvider.value(
            value: playerCubit,
            child: const FullscreenPlayerScreen(),
          );
        },
        transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
              ),
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.18),
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PlayerCubit, PlayerState>(
      listenWhen: (prev, curr) =>
          prev.currentTrack?.coverUrl != curr.currentTrack?.coverUrl,
      listener: (context, state) {
        final cover = state.currentTrack?.coverUrl;
        if (cover != null && cover.isNotEmpty) {
          _extractDominantColor(cover);
        }
      },
      child: BlocSelector<PlayerCubit, PlayerState, TrackModel?>(
        selector: (state) => state.currentTrack,
        builder: (context, track) {
          if (track == null) return const SizedBox.shrink();

          return ValueListenableBuilder<String>(
            valueListenable: StorageService.playerStyleNotifier,
            builder: (context, playerStyle, _) {
              final bool isVertical = playerStyle != 'default';
              final bool usesImmersiveMini = isVertical;
              final bool isResponsiveFloating =
                  MediaQuery.sizeOf(context).width >= 600;

              final Widget capsule = RepaintBoundary(
                child: GestureDetector(
                  onTap: () => _openFullscreenPlayer(context),
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0.0;
                    if (velocity < -320) {
                      HapticFeedback.lightImpact();
                      context.read<PlayerCubit>().playNext();
                    } else if (velocity > 320) {
                      HapticFeedback.lightImpact();
                      context.read<PlayerCubit>().playPrevious();
                    }
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: usesImmersiveMini
                        ? _buildImmersiveMiniPlayer(
                            context,
                            track,
                            isVerticalGauge: isVertical,
                          )
                        : _buildStandardMiniPlayer(context, track),
                  ),
                ),
              ).animate().slideY(
                    begin: isResponsiveFloating ? -0.35 : 1.0,
                    end: 0,
                    duration: AppAnimations.normal,
                    curve: AppAnimations.decelerate,
                  );

              if (isResponsiveFloating) {
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: capsule,
                );
              }

              return capsule;
            },
          );
        },
      ),
    );
  }

  /// ===========================================================================
  /// MINI-LECTEUR IMMERSIF (« FUSION » & « PRISME VERTICAL »)
  /// Pochette bord-à-bord à gauche qui se fond horizontalement dans la palette
  /// ===========================================================================
  Widget _buildImmersiveMiniPlayer(
    BuildContext context,
    TrackModel track, {
    required bool isVerticalGauge,
  }) {
    final palette = _immersivePalette;
    final Color midBlend = Color.lerp(palette.midColor, palette.deepColor, 0.52)!;

    return Container(
      key: ValueKey('mini_player_immersive_$isVerticalGauge'),
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.spacingMd,
        AppDimensions.spacingXs,
        AppDimensions.spacingMd,
        6,
      ),
      height: 68.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.36),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: palette.dominantColor.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Couche atmosphérique + Pochette bord-à-bord fondue (isolée en cache GPU)
            RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Dégradé chromatique horizontal harmonisé
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        stops: const [0.0, 0.46, 1.0],
                        colors: [
                          palette.midColor,
                          midBlend,
                          palette.deepColor,
                        ],
                      ),
                    ),
                  ),

                  // Halo flouté ultra-léger (96px max en VRAM) pour diffuser les teintes spatiales
                  if (track.coverUrl.isNotEmpty)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.36,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: 18,
                            sigmaY: 18,
                            tileMode: TileMode.clamp,
                          ),
                          child: SonoritizArtwork(
                            imageUrl: track.coverUrl,
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: 0,
                            fit: BoxFit.cover,
                            alignment: Alignment.centerRight,
                            cacheMaxDimension: 96,
                          ),
                        ),
                      ),
                    ),

                  // Pochette bord-à-bord à gauche qui se dissout vers la droite (courbe en S cosinus à 7 stops)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.48,
                      heightFactor: 1.0,
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (Rect bounds) {
                          return const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            stops: [0.0, 0.34, 0.54, 0.68, 0.80, 0.91, 1.0],
                            colors: [
                              Color(0xFFFFFFFF),
                              Color(0xFFFFFFFF),
                              Color(0xDBFFFFFF),
                              Color(0x8FFFFFFF),
                              Color(0x40FFFFFF),
                              Color(0x12FFFFFF),
                              Color(0x00FFFFFF),
                            ],
                          ).createShader(bounds);
                        },
                        child: SonoritizArtwork(
                          imageUrl: track.coverUrl,
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 0,
                          fit: BoxFit.cover,
                          cacheMaxDimension: 220,
                        ),
                      ),
                    ),
                  ),

                  // Voile d'harmonisation horizontal garantissant la lisibilité du texte blanc
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        stops: const [0.0, 0.18, 0.42, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.04),
                          palette.midColor.withValues(alpha: 0.22),
                          midBlend.withValues(alpha: 0.66),
                          palette.deepColor.withValues(alpha: 0.86),
                        ],
                      ),
                    ),
                  ),

                  // Bordure spéculaire périphérique ultra-fine
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                        width: 0.9,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Contenu éditorial & Contrôles sculptés
            Padding(
              padding: const EdgeInsets.only(
                left: 74.0,
                right: 10.0,
              ),
              child: Row(
                children: [
                  // Titre & Artiste flottant dans la zone de fusion
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x88000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2.5),
                        ArtistNameDisplay(
                          artistName: track.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 12.2,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(
                                color: Color(0x66000000),
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Bouton Favori / Superlike compact
                  PlayerFavoriteButton(
                    track: track,
                    size: 36,
                    iconSize: 20,
                  ),

                  const SizedBox(width: 4),

                  // Bouton Play/Pause central blanc pur (signature Fusion)
                  BlocSelector<PlayerCubit, PlayerState, (bool, bool)>(
                    selector: (state) => (state.isPlaying, state.isBuffering),
                    builder: (context, s) {
                      final (isPlaying, isBuffering) = s;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.read<PlayerCubit>().togglePlayPause();
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.28),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: isBuffering
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: palette.deepColor,
                                    ),
                                  )
                                : Icon(
                                    isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: palette.deepColor,
                                    size: 23,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 6),

                  // Bouton Suivant circulaire translucide
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.read<PlayerCubit>().playNext();
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                          width: 0.8,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Barre de progression lumineuse à la couleur de la pochette (isolée par RepaintBoundary)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: Container(
                  height: 2.5,
                  color: Colors.white.withValues(alpha: 0.16),
                  alignment: Alignment.centerLeft,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return BlocSelector<PlayerCubit, PlayerState, double>(
                        selector: (state) {
                          if (state.duration.inMilliseconds > 0) {
                            return (state.position.inMilliseconds /
                                    state.duration.inMilliseconds)
                                .clamp(0.0, 1.0);
                          }
                          return 0.0;
                        },
                        builder: (context, progress) {
                          return Container(
                            width: constraints.maxWidth * progress,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  palette.accentColor,
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ===========================================================================
  /// MINI-LECTEUR CLASSIQUE / STANDARD
  /// ===========================================================================
  Widget _buildStandardMiniPlayer(BuildContext context, TrackModel track) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = _dominantColor ?? colorScheme.surface;

    return Container(
      key: const ValueKey('mini_player_standard'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          height: AppDimensions.miniPlayerHeight,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
                bgColor.withValues(alpha: 0.45), const Color(0xFF141414)),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.12), width: 1.0),
          ),
          child: Stack(
            children: [
              // Progress Bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: RepaintBoundary(
                  child: Container(
                    height: 2,
                    color: Colors.white.withValues(alpha: 0.2),
                    alignment: Alignment.centerLeft,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return BlocSelector<PlayerCubit, PlayerState, double>(
                          selector: (state) {
                            if (state.duration.inMilliseconds > 0) {
                              return (state.position.inMilliseconds /
                                      state.duration.inMilliseconds)
                                  .clamp(0.0, 1.0);
                            }
                            return 0.0;
                          },
                          builder: (context, progress) {
                            return Container(
                              width: constraints.maxWidth * progress,
                              color: Colors.white,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingSm),
                child: Row(
                  children: [
                    // Cover (sans Hero conflictuel)
                    SonoritizArtwork(
                      imageUrl: track.coverUrl,
                      width: 48,
                      height: 48,
                      borderRadius: AppDimensions.radiusMd,
                      cacheMaxDimension: 160,
                    ),
                    const SizedBox(width: AppDimensions.spacingMd),

                    // Title & Artist
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          ArtistNameDisplay(
                            artistName: track.artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),

                    // Controls
                    BlocSelector<PlayerCubit, PlayerState, (bool, bool)>(
                      selector: (state) =>
                          (state.isPlaying, state.isBuffering),
                      builder: (context, s) {
                        final (isPlaying, isBuffering) = s;
                        if (isBuffering) {
                          return Container(
                            width: AppDimensions.minTouchTarget,
                            height: AppDimensions.minTouchTarget,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const RepaintBoundary(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          );
                        }
                        return SonoritizIconButton(
                          icon: isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          tooltip: isPlaying ? "Pause" : "Lecture",
                          color: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          onPressed: () =>
                              context.read<PlayerCubit>().togglePlayPause(),
                        )
                            .animate(target: isPlaying ? 1 : 0)
                            .scaleXY(
                                end: 1.05, duration: AppAnimations.fast);
                      },
                    ),
                    const SizedBox(width: AppDimensions.spacingXs),
                    SonoritizIconButton(
                      icon: Icons.skip_next_rounded,
                      tooltip: "Suivant",
                      color: Colors.white,
                      onPressed: () => context.read<PlayerCubit>().playNext(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
