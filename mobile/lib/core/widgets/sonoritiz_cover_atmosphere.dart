import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart' as import_go_router;

import '../../features/library/data/repositories/library_repository.dart';
import '../../features/player/data/models/track_model.dart';
import '../../features/player/presentation/cubit/player_cubit.dart';
import '../../features/player/presentation/cubit/player_state.dart';
import '../../features/player/presentation/widgets/player_components/immersive_player_widgets.dart';
import '../services/palette_service.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import 'playlist_cover_mosaic.dart';
import 'sonoritiz_artwork.dart';
import 'sonoritiz_page_title.dart';
import 'sonoritiz_track_tile.dart';

/// Arrière-plan atmosphérique pleine page animé par la couleur dominante
/// de la pochette (aligné sur le lecteur plein écran Sonoritiz).
class SonoritizCoverAtmosphere extends StatefulWidget {
  final String coverUrl;
  final Widget child;
  final Color? accentFallback;

  const SonoritizCoverAtmosphere({
    super.key,
    required this.coverUrl,
    required this.child,
    this.accentFallback,
  });

  @override
  State<SonoritizCoverAtmosphere> createState() =>
      _SonoritizCoverAtmosphereState();
}

class _SonoritizCoverAtmosphereState extends State<SonoritizCoverAtmosphere> {
  ImmersivePalette _palette = ImmersivePalette.fallback;

  @override
  void initState() {
    super.initState();
    _resolvePalette(widget.coverUrl);
  }

  @override
  void didUpdateWidget(covariant SonoritizCoverAtmosphere oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl ||
        oldWidget.accentFallback != widget.accentFallback) {
      _resolvePalette(widget.coverUrl);
    }
  }

  void _resolvePalette(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      final fb = widget.accentFallback;
      setState(() {
        _palette = fb != null
            ? ImmersivePalette.fromExtracted(dominant: fb, vibrant: fb)
            : ImmersivePalette.fallback;
      });
      return;
    }

    final cached = PaletteService.getCached(trimmed);
    if (cached != null) {
      if (mounted) setState(() => _palette = cached);
      return;
    }

    PaletteService.getPalette(trimmed).then((resolved) {
      if (!mounted || widget.coverUrl.trim() != trimmed) return;
      setState(() => _palette = resolved);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color glowPrimary = widget.coverUrl.trim().isNotEmpty
        ? _palette.dominantColor
        : (widget.accentFallback ?? _palette.dominantColor);

    return ColoredBox(
      color: _palette.deepColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ImmersiveAtmosphereBackground(
              coverUrl: widget.coverUrl,
              palette: _palette,
            ),
          ),
          // Halo étendu sur toute la hauteur de la page (haut, centre et bas)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: AppAnimations.slow,
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.55),
                    radius: 1.35,
                    colors: [
                      glowPrimary.withValues(alpha: 0.34),
                      _palette.midColor.withValues(alpha: 0.24),
                      _palette.deepColor.withValues(alpha: 0.58),
                    ],
                    stops: const [0.0, 0.52, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.10),
                      glowPrimary.withValues(alpha: 0.12),
                      _palette.deepColor.withValues(alpha: 0.72),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Design unifié Sonoritiz pour toutes les pages d'albums, playlists et listes de sons :
/// - Lueur dominante pleine page issue de la pochette
/// - En-tête éditorial centré avec pochette ou triptyque 3 pochettes
/// - Titre souligné en orange (SonoritizPageTitle) avec typographie agrandie
/// - Barre d'actions unifiée (Lire / Aléatoire / bouton secondaire)
/// - Liste des pistes épurée et lisible
class SonoritizCollectionScaffold extends StatefulWidget {
  final String title;
  final String? badgeLabel;
  final String? subtitle;
  final VoidCallback? onSubtitleTap;
  final String? metadata;
  final String coverUrl;
  final PlaylistModel? playlistMosaic;
  final List<TrackModel> tracks;
  final String playbackSource;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String emptyMessage;
  final bool showTrackCovers;
  final Color? fallbackAccentColor;
  final List<Widget> appBarActions;
  final Widget? trailingActionButton;
  final List<Widget> extraHeaderSlivers;
  final List<Widget> footerSlivers;
  final Widget Function(BuildContext context, TrackModel track, int index)?
      trackBuilder;

  const SonoritizCollectionScaffold({
    super.key,
    required this.title,
    this.badgeLabel,
    this.subtitle,
    this.onSubtitleTap,
    this.metadata,
    this.coverUrl = '',
    this.playlistMosaic,
    required this.tracks,
    required this.playbackSource,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.emptyMessage = 'Aucun morceau disponible pour le moment.',
    this.showTrackCovers = true,
    this.fallbackAccentColor,
    this.appBarActions = const [],
    this.trailingActionButton,
    this.extraHeaderSlivers = const [],
    this.footerSlivers = const [],
    this.trackBuilder,
  });

  @override
  State<SonoritizCollectionScaffold> createState() =>
      _SonoritizCollectionScaffoldState();
}

class _SonoritizCollectionScaffoldState
    extends State<SonoritizCollectionScaffold> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _collapseProgress = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final progress = (_scrollController.offset / 220.0).clamp(0.0, 1.0);
    if ((progress - _collapseProgress.value).abs() > 0.01) {
      _collapseProgress.value = progress;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _collapseProgress.dispose();
    super.dispose();
  }

  String _resolveHeroCoverUrl() {
    if (widget.coverUrl.trim().isNotEmpty) return widget.coverUrl.trim();
    if (widget.playlistMosaic != null) {
      if (widget.playlistMosaic!.coverUrl.trim().isNotEmpty) {
        return widget.playlistMosaic!.coverUrl.trim();
      }
      for (final t in widget.playlistMosaic!.tracks) {
        if (t.coverUrl.trim().isNotEmpty) return t.coverUrl.trim();
      }
    }
    for (final t in widget.tracks) {
      if (t.coverUrl.trim().isNotEmpty) return t.coverUrl.trim();
    }
    return '';
  }

  String _formatTotalDuration(List<TrackModel> tracks) {
    int totalSeconds = 0;
    for (final t in tracks) {
      totalSeconds += t.durationSeconds > 0 ? t.durationSeconds : 195;
    }
    if (totalSeconds <= 0) return '';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours h ${minutes.toString().padLeft(2, '0')} min';
    }
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final String effectiveCover = _resolveHeroCoverUrl();
    final String totalDuration = _formatTotalDuration(widget.tracks);
    final String autoMetadata = widget.tracks.isEmpty
        ? ''
        : '${widget.tracks.length} ${widget.tracks.length > 1 ? 'titres' : 'titre'}${totalDuration.isNotEmpty ? ' • $totalDuration' : ''}';
    final String effectiveMetadata =
        (widget.metadata != null && widget.metadata!.isNotEmpty)
            ? widget.metadata!
            : autoMetadata;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      body: SonoritizCoverAtmosphere(
        coverUrl: effectiveCover,
        accentFallback: widget.fallbackAccentColor,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            ValueListenableBuilder<double>(
              valueListenable: _collapseProgress,
              builder: (context, collapse, _) {
                return SliverAppBar(
                  backgroundColor:
                      const Color(0xFF0C0C0E).withValues(alpha: collapse * 0.90),
                  elevation: 0,
                  pinned: true,
                  toolbarHeight: 62,
                  leading: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () {
                      final router = import_go_router.GoRouter.maybeOf(context);
                      if (router != null && router.canPop()) {
                        router.pop();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                  ),
                  title: Opacity(
                    opacity: collapse,
                    child: Row(
                      children: [
                        if (widget.playlistMosaic != null)
                          PlaylistCoverMosaic(
                            playlist: widget.playlistMosaic!,
                            size: 32,
                            height: 34,
                            borderRadius: 6,
                          )
                        else if (effectiveCover.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SonoritizArtwork(
                              imageUrl: effectiveCover,
                              width: 32,
                              height: 32,
                              borderRadius: 0,
                              cacheMaxDimension: 120,
                            ),
                          ),
                        if (widget.playlistMosaic != null ||
                            effectiveCover.isNotEmpty)
                          const SizedBox(width: 10),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SonoritizPageTitle(
                              title: widget.title,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    if (collapse > 0.72 && widget.tracks.isNotEmpty)
                      IconButton(
                        tooltip: "Lire",
                        onPressed: () => context.read<PlayerCubit>().playTrack(
                              widget.tracks.first,
                              queue: widget.tracks,
                              source: widget.playbackSource,
                            ),
                        icon: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 21,
                          ),
                        ),
                      ),
                    ...widget.appBarActions,
                  ],
                );
              },
            ),

            // --- EN-TÊTE ÉDITORIAL UNIFIÉ ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Column(
                  children: [
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.60),
                              blurRadius: 34,
                              spreadRadius: -4,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: widget.playlistMosaic != null
                            ? PlaylistCoverMosaic(
                                playlist: widget.playlistMosaic!,
                                size: 216,
                                height: 230,
                                borderRadius: 18,
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: effectiveCover.isNotEmpty
                                    ? SonoritizArtwork(
                                        imageUrl: effectiveCover,
                                        width: 218,
                                        height: 218,
                                        borderRadius: 18,
                                        cacheMaxDimension: 600,
                                      )
                                    : Container(
                                        width: 218,
                                        height: 218,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              (widget.fallbackAccentColor ??
                                                      AppColors.primary)
                                                  .withValues(alpha: 0.35),
                                              const Color(0xFF17171E),
                                            ],
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.graphic_eq_rounded,
                                          color: widget.fallbackAccentColor ??
                                              AppColors.primary,
                                          size: 56,
                                        ),
                                      ),
                              ),
                      ),
                    ).animate().fadeIn(duration: 280.ms).scale(
                          begin: const Offset(0.96, 0.96),
                          end: const Offset(1.0, 1.0),
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 20),
                    if (widget.badgeLabel != null &&
                        widget.badgeLabel!.isNotEmpty) ...[
                      Text(
                        widget.badgeLabel!.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Center(
                      child: SonoritizPageTitle(
                        title: widget.title,
                        fontSize: 28,
                        maxLines: 2,
                        centered: true,
                      ),
                    ),
                    if (widget.subtitle != null &&
                        widget.subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: widget.onSubtitleTap,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                widget.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: widget.onSubtitleTap != null
                                      ? AppColors.primary
                                      : Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                            if (widget.onSubtitleTap != null) ...[
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (effectiveMetadata.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        effectiveMetadata,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (!widget.isLoading && widget.tracks.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      BlocBuilder<PlayerCubit, PlayerState>(
                        builder: (context, playerState) {
                          final bool isThisCollectionPlaying =
                              playerState.isPlaying &&
                                  playerState.currentTrack != null &&
                                  widget.tracks.any((t) =>
                                      t.id == playerState.currentTrack!.id);

                          return Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.black,
                                      elevation: 0,
                                      shape: const StadiumBorder(),
                                    ),
                                    onPressed: () {
                                      final cubit =
                                          context.read<PlayerCubit>();
                                      if (isThisCollectionPlaying) {
                                        cubit.togglePlayPause();
                                      } else {
                                        cubit.playTrack(
                                          widget.tracks.first,
                                          queue: widget.tracks,
                                          source: widget.playbackSource,
                                        );
                                      }
                                    },
                                    icon: Icon(
                                      isThisCollectionPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 24,
                                    ),
                                    label: Text(
                                      isThisCollectionPlaying
                                          ? "Pause"
                                          : "Lire",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: TextButton.icon(
                                    style: TextButton.styleFrom(
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.10),
                                      foregroundColor: Colors.white,
                                      shape: const StadiumBorder(),
                                    ),
                                    onPressed: () {
                                      final shuffled = List<TrackModel>.from(
                                          widget.tracks)
                                        ..shuffle();
                                      context.read<PlayerCubit>().playTrack(
                                            shuffled.first,
                                            queue: shuffled,
                                            source: widget.playbackSource,
                                          );
                                    },
                                    icon: const Icon(Icons.shuffle_rounded,
                                        size: 20),
                                    label: const Text(
                                      "Aléatoire",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (widget.trailingActionButton != null) ...[
                                const SizedBox(width: 10),
                                widget.trailingActionButton!,
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            ...widget.extraHeaderSlivers,

            if (widget.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (widget.errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.white70, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          widget.errorMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (widget.onRetry != null) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: widget.onRetry,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text(
                              "Réessayer",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else if (widget.tracks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 32),
                    child: Text(
                      widget.emptyMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final track = widget.tracks[index];
                    if (widget.trackBuilder != null) {
                      return widget.trackBuilder!(context, track, index);
                    }
                    return SonoritizTrackTile(
                      track: track,
                      queue: widget.tracks,
                      index: index,
                      showCover: widget.showTrackCovers,
                      playbackSource: widget.playbackSource,
                    );
                  },
                  childCount: widget.tracks.length,
                ),
              ),

            ...widget.footerSlivers,

            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),
      ),
    );
  }
}
