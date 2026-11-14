import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../../core/audio/audio_device_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/artist_name_display.dart';
import '../../../../library/presentation/cubit/library_cubit.dart';
import '../../../../library/presentation/cubit/library_state.dart';
import '../../../../offline/presentation/cubit/download_cubit.dart';
import '../../../data/models/track_model.dart';
import '../../cubit/superlike_cubit.dart';
import '../../cubit/superlike_state.dart';
import 'sonoritiz_player_icons.dart';

/// ============================================================================
/// 1. LE DOCK SOLAIRE FLOTTANT ("Solar Dock Island")
/// Reproduit fidèlement la carte tactile flottante lumineuse en bas de l'écran,
/// avec nos éléments de studio et nos icônes néo-minimalistes sur-mesure.
/// ============================================================================
class SpecialSolarDockCard extends StatelessWidget {
  final TrackModel currentTrack;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final bool isShuffleModeEnabled;
  final LoopMode loopMode;
  final bool isVideoMode;
  final bool isVideoLoading;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onLyricsTapped;
  final VoidCallback onQueueTapped;
  final VoidCallback onVideoTapped;

  const SpecialSolarDockCard({
    super.key,
    required this.currentTrack,
    required this.isPlaying,
    required this.isBuffering,
    required this.position,
    required this.duration,
    required this.isShuffleModeEnabled,
    required this.loopMode,
    required this.isVideoMode,
    required this.isVideoLoading,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
    required this.onSeek,
    required this.onLyricsTapped,
    required this.onQueueTapped,
    required this.onVideoTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF201712), // Teinte obsidienne solaire avec micro-chaleur cuivrée
            Color(0xFF13100F),
          ],
        ),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.38),
          width: 1.2,
        ),
        boxShadow: [
          // Halo d'ambiance néon solaire
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 28,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
          // Ombre physique profonde
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. En-tête : Titre + Nom d'artiste à gauche, bouton Like sculpté à droite
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentTrack.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ArtistNameDisplay(
                      artistName: currentTrack.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildFavoriteButton(context),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Vibrations acoustiques fines (Spectre d'ondes)
          SpecialWaveformRow(
            position: position,
            duration: duration,
            isPlaying: isPlaying,
            trackId: currentTrack.id,
            onSeek: onSeek,
            height: 32,
            paddingHorizontal: 2,
          ),

          const SizedBox(height: 4),

          // 3. Barre de progression fine avec curseur rond et compteurs de temps
          SpecialThinProgressBar(
            position: position,
            duration: duration,
            onSeek: onSeek,
            paddingHorizontal: 2,
          ),

          const SizedBox(height: 12),

          // 4. Pastilles studio compactes avec nos icônes personnalisées
          Row(
            children: [
              Expanded(
                child: _buildStudioPill(
                  label: isVideoLoading ? '...' : (isVideoMode ? 'Audio' : 'Clip'),
                  icon: SonoritizVideoIcon(
                    size: 14,
                    color: isVideoMode ? Colors.white : const Color(0xFFDCA17A),
                  ),
                  isFilledOrange: isVideoMode,
                  onTap: onVideoTapped,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStudioPill(
                  label: 'Paroles',
                  icon: const SonoritizLyricsIcon(
                    size: 14,
                    color: Color(0xFFDCA17A),
                  ),
                  isFilledOrange: false,
                  onTap: onLyricsTapped,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStudioPill(
                  label: 'File',
                  icon: const SonoritizQueueIcon(
                    size: 14,
                    color: Color(0xFFDCA17A),
                  ),
                  isFilledOrange: false,
                  onTap: onQueueTapped,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDownloadPill(context),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 5. Contrôles de lecture principaux avec nos icônes vectorielles ultra-stylisées
          SpecialPrimaryControls(
            isPlaying: isPlaying,
            isBuffering: isBuffering,
            isShuffleModeEnabled: isShuffleModeEnabled,
            loopMode: loopMode,
            onPlayPause: onPlayPause,
            onPrevious: onPrevious,
            onNext: onNext,
            onShuffle: onShuffle,
            onRepeat: onRepeat,
            paddingHorizontal: 6,
          ),

          const SizedBox(height: 8),

          // 6. Sortie audio minimaliste (ex: Galaxy Buds)
          const SpecialAudioDeviceLabel(),
        ],
      ),
    );
  }

  Widget _buildFavoriteButton(BuildContext context) {
    return BlocBuilder<SuperlikeCubit, SuperlikeState>(
      builder: (context, slState) {
        final isSuper = slState.isSuperliked(currentTrack.id);
        return BlocBuilder<LibraryCubit, LibraryState>(
          builder: (context, _) {
            final isFav = context.read<LibraryCubit>().isFavorite(
                  currentTrack.id,
                  title: currentTrack.title,
                  artist: currentTrack.artistName,
                );
            final bool isActive = isSuper || isFav;

            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                final cubit = context.read<LibraryCubit>();
                if (isFav) {
                  cubit.removeFavorite(currentTrack.id);
                } else {
                  cubit.addFavorite(currentTrack);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: isActive
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.16),
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: SonoritizHeartIcon(
                    size: 20,
                    color: isActive ? AppColors.primary : Colors.white70,
                    isFilled: isActive,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDownloadPill(BuildContext context) {
    return BlocBuilder<DownloadCubit, DownloadState>(
      builder: (context, downloadState) {
        bool isDownloaded = false;
        bool isDownloading = false;
        double progress = 0.0;

        if (downloadState is DownloadStateData) {
          isDownloaded = downloadState.downloadedIds.contains(currentTrack.id);
          if (downloadState.downloadingProgress.containsKey(currentTrack.id)) {
            isDownloading = true;
            progress = downloadState.downloadingProgress[currentTrack.id]!;
          }
        }

        if (isDownloading) {
          final pct = (progress * 100).clamp(0, 99).toInt();
          return _buildStudioPill(
            label: '$pct%',
            icon: const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: Colors.white,
              ),
            ),
            isFilledOrange: true,
            onTap: () {},
          );
        }

        return _buildStudioPill(
          label: isDownloaded ? 'Prêt' : 'Hors-ligne',
          icon: SonoritizDownloadIcon(
            size: 14,
            color: isDownloaded ? Colors.white : const Color(0xFFDCA17A),
            isCompleted: isDownloaded,
          ),
          isFilledOrange: isDownloaded,
          onTap: () {
            if (isDownloaded) {
              context.read<DownloadCubit>().removeDownload(currentTrack.id);
            } else {
              context.read<DownloadCubit>().downloadTrack(currentTrack);
            }
          },
        );
      },
    );
  }

  Widget _buildStudioPill({
    required String label,
    required Widget icon,
    required bool isFilledOrange,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isFilledOrange
              ? AppColors.primary
              : const Color(0xFF281C14).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFilledOrange
                ? AppColors.primary
                : const Color(0xFF5A3016).withValues(alpha: 0.55),
            width: 0.9,
          ),
          boxShadow: isFilledOrange
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isFilledOrange ? Colors.white : const Color(0xFFDCA17A),
                  fontSize: 11,
                  fontWeight: isFilledOrange ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// 2. SPECTRE ACOUSTIQUE VERTICAL
/// ============================================================================
class SpecialWaveformRow extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final String trackId;
  final ValueChanged<Duration> onSeek;
  final double height;
  final double paddingHorizontal;

  const SpecialWaveformRow({
    super.key,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.trackId,
    required this.onSeek,
    this.height = 36,
    this.paddingHorizontal = 26,
  });

  @override
  State<SpecialWaveformRow> createState() => _SpecialWaveformRowState();
}

class _SpecialWaveformRowState extends State<SpecialWaveformRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _vibController;
  late List<double> _baseAmplitudes;

  @override
  void initState() {
    super.initState();
    _baseAmplitudes = _generateAmplitudes(widget.trackId);
    _vibController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) {
      _vibController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SpecialWaveformRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId) {
      _baseAmplitudes = _generateAmplitudes(widget.trackId);
    }
    if (widget.isPlaying && !_vibController.isAnimating) {
      _vibController.repeat();
    } else if (!widget.isPlaying && _vibController.isAnimating) {
      _vibController.stop();
    }
  }

  @override
  void dispose() {
    _vibController.dispose();
    super.dispose();
  }

  List<double> _generateAmplitudes(String seedStr) {
    const int barCount = 64;
    final int seed = seedStr.codeUnits.fold<int>(17, (a, b) => (a * 31 + b) & 0x7FFFFFFF);
    final rng = math.Random(seed);
    return List<double>.generate(barCount, (i) {
      final double norm = i / (barCount - 1);
      final double envelope = math.sin(norm * math.pi);
      final double lobe1 = (math.sin(norm * math.pi * 3.0)).abs();
      final double jitter = 0.35 + rng.nextDouble() * 0.65;
      final double val = (0.12 + 0.88 * envelope * (0.45 + 0.55 * lobe1) * jitter).clamp(0.10, 1.0);
      return val;
    });
  }

  void _handleTouch(Offset localPosition, double width) {
    if (width <= 0 || widget.duration.inMilliseconds <= 0) return;
    final ratio = (localPosition.dx / width).clamp(0.0, 1.0);
    final targetMs = (widget.duration.inMilliseconds * ratio).round();
    widget.onSeek(Duration(milliseconds: targetMs));
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration.inMilliseconds;
    final posMs = widget.position.inMilliseconds;
    final progress = totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.paddingHorizontal),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _handleTouch(d.localPosition, constraints.maxWidth),
            onHorizontalDragUpdate: (d) => _handleTouch(d.localPosition, constraints.maxWidth),
            child: SizedBox(
              height: widget.height,
              width: double.infinity,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _vibController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size(constraints.maxWidth, widget.height),
                      painter: _AcousticWaveformPainter(
                        amplitudes: _baseAmplitudes,
                        progress: progress,
                        phase: _vibController.value * math.pi * 2,
                        isPlaying: widget.isPlaying,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AcousticWaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final double progress;
  final double phase;
  final bool isPlaying;

  _AcousticWaveformPainter({
    required this.amplitudes,
    required this.progress,
    required this.phase,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int count = amplitudes.length;
    if (count == 0) return;

    final double cy = size.height / 2;
    final double spacing = size.width / count;
    final double strokeW = (spacing * 0.42).clamp(1.2, 2.0);

    final centerLinePaint = Paint()
      ..color = const Color(0xFFFA7921).withValues(alpha: 0.16)
      ..strokeWidth = 0.6;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), centerLinePaint);

    final inactivePaint = Paint()
      ..color = const Color(0xFF3E2416)
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    final activeOuterPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    final activeCorePaint = Paint()
      ..color = const Color(0xFFFFE5B4)
      ..strokeWidth = (strokeW * 0.70).clamp(0.9, 1.5)
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < count; i++) {
      final double barProgress = i / (count - 1);
      final double x = i * spacing + spacing / 2;

      double amp = amplitudes[i];
      if (isPlaying) {
        final double wave = math.sin(phase + i * 0.42) * 0.16 +
            math.cos(phase * 1.5 - i * 0.27) * 0.10;
        amp = (amp + wave * amp).clamp(0.10, 1.0);
      }

      final double halfH = (size.height * 0.46) * amp;
      final bool isActive = barProgress <= progress;

      if (isActive) {
        canvas.drawLine(Offset(x, cy - halfH), Offset(x, cy + halfH), activeOuterPaint);
        final double coreHalfH = halfH * 0.40;
        if (coreHalfH > 1.2) {
          canvas.drawLine(Offset(x, cy - coreHalfH), Offset(x, cy + coreHalfH), activeCorePaint);
        }
      } else {
        canvas.drawLine(Offset(x, cy - halfH), Offset(x, cy + halfH), inactivePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AcousticWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phase != phase ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.amplitudes != amplitudes;
  }
}

/// ============================================================================
/// 3. BARRE DE PROGRESSION FINE
/// ============================================================================
class SpecialThinProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final double paddingHorizontal;

  const SpecialThinProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.paddingHorizontal = 26,
  });

  @override
  State<SpecialThinProgressBar> createState() => _SpecialThinProgressBarState();
}

class _SpecialThinProgressBarState extends State<SpecialThinProgressBar> {
  double? _dragRatio;

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration.inMilliseconds;
    final posMs = widget.position.inMilliseconds;
    final currentRatio = _dragRatio ??
        (totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0);

    final displayedPosition = _dragRatio != null && totalMs > 0
        ? Duration(milliseconds: (totalMs * _dragRatio!).round())
        : widget.position;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.paddingHorizontal),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  if (width <= 0 || totalMs <= 0) return;
                  final r = (d.localPosition.dx / width).clamp(0.0, 1.0);
                  widget.onSeek(Duration(milliseconds: (totalMs * r).round()));
                },
                onHorizontalDragStart: (d) {
                  if (width <= 0) return;
                  setState(() {
                    _dragRatio = (d.localPosition.dx / width).clamp(0.0, 1.0);
                  });
                },
                onHorizontalDragUpdate: (d) {
                  if (width <= 0) return;
                  setState(() {
                    _dragRatio = (d.localPosition.dx / width).clamp(0.0, 1.0);
                  });
                },
                onHorizontalDragEnd: (_) {
                  if (_dragRatio != null && totalMs > 0) {
                    widget.onSeek(Duration(milliseconds: (totalMs * _dragRatio!).round()));
                  }
                  setState(() => _dragRatio = null);
                },
                onHorizontalDragCancel: () => setState(() => _dragRatio = null),
                child: SizedBox(
                  height: 16,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _ThinProgressLinePainter(ratio: currentRatio),
                  ),
                ),
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(displayedPosition),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                _formatDuration(widget.duration),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThinProgressLinePainter extends CustomPainter {
  final double ratio;

  _ThinProgressLinePainter({required this.ratio});

  @override
  void paint(Canvas canvas, Size size) {
    final double cy = size.height / 2;
    final double activeX = (size.width * ratio).clamp(0.0, size.width);

    final bgPaint = Paint()
      ..color = const Color(0xFF2E2420)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(activeX, cy), Offset(size.width, cy), bgPaint);

    final activePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, cy), Offset(activeX, cy), activePaint);

    final glowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(Offset(activeX, cy), 6.5, glowPaint);

    final thumbPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(activeX, cy), 5.0, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _ThinProgressLinePainter oldDelegate) =>
      oldDelegate.ratio != ratio;
}

/// ============================================================================
/// 4. CONTRÔLES PRINCIPAUX AVEC ICÔNES NÉO-MINIMALISTES GÉOMÉTRIQUES
/// ============================================================================
class SpecialPrimaryControls extends StatelessWidget {
  final bool isPlaying;
  final bool isBuffering;
  final bool isShuffleModeEnabled;
  final LoopMode loopMode;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;
  final double paddingHorizontal;

  const SpecialPrimaryControls({
    super.key,
    required this.isPlaying,
    required this.isBuffering,
    required this.isShuffleModeEnabled,
    required this.loopMode,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
    this.paddingHorizontal = 24,
  });

  @override
  Widget build(BuildContext context) {
    final bool isRepeatActive = loopMode != LoopMode.off;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: paddingHorizontal),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Bouton Aléatoire
          GestureDetector(
            onTap: onShuffle,
            behavior: HitTestBehavior.opaque,
            child: Tooltip(
              message: 'Lecture aléatoire',
              child: SizedBox(
                width: 42,
                height: 42,
                child: Center(
                  child: SonoritizShuffleIcon(
                    size: 22,
                    color: isShuffleModeEnabled ? AppColors.primary : Colors.white.withValues(alpha: 0.65),
                    isActive: isShuffleModeEnabled,
                  ),
                ),
              ),
            ),
          ),

          // Bouton Précédent
          GestureDetector(
            onTap: onPrevious,
            behavior: HitTestBehavior.opaque,
            child: Tooltip(
              message: 'Précédent',
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: SonoritizPrevIcon(
                    size: 26,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Bouton Play/Pause central imposant et lumineux
          GestureDetector(
            onTap: onPlayPause,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.48),
                    blurRadius: 22,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: isBuffering
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2.6,
                        ),
                      )
                    : (isPlaying
                        ? const SonoritizPauseIcon(size: 26, color: Colors.black)
                        : const SonoritizPlayIcon(size: 26, color: Colors.black)),
              ),
            ),
          ),

          // Bouton Suivant
          GestureDetector(
            onTap: onNext,
            behavior: HitTestBehavior.opaque,
            child: Tooltip(
              message: 'Suivant',
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: SonoritizNextIcon(
                    size: 26,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Bouton Répéter
          GestureDetector(
            onTap: onRepeat,
            behavior: HitTestBehavior.opaque,
            child: Tooltip(
              message: 'Répéter',
              child: SizedBox(
                width: 42,
                height: 42,
                child: Center(
                  child: SonoritizRepeatIcon(
                    size: 22,
                    color: isRepeatActive ? AppColors.primary : Colors.white.withValues(alpha: 0.65),
                    isActive: isRepeatActive,
                    isOne: loopMode == LoopMode.one,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// 5. SORTIE AUDIO MINIMALISTE (ex: Galaxy Buds)
/// ============================================================================
class SpecialAudioDeviceLabel extends StatelessWidget {
  const SpecialAudioDeviceLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final deviceService = AudioDeviceService();

    return StreamBuilder<AudioOutputDevice>(
      stream: deviceService.deviceStream,
      initialData: deviceService.currentDevice,
      builder: (context, snapshot) {
        final device = snapshot.data ?? deviceService.currentDevice;
        final bool isExternal = device.isExternal;

        return Center(
          child: GestureDetector(
            onTap: () => deviceService.openOutputSwitcher(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    device.icon,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isExternal ? device.name : "Haut-parleur",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.80),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ============================================================================
/// 6. ANCIENNE GRILLE DES PILULES STUDIO (pour compatibilité)
/// ============================================================================
class SpecialStudioPillsGrid extends StatelessWidget {
  final TrackModel currentTrack;
  final bool isVideoMode;
  final bool isVideoLoading;
  final VoidCallback onLyricsTapped;
  final VoidCallback onQueueTapped;
  final VoidCallback onVideoTapped;

  const SpecialStudioPillsGrid({
    super.key,
    required this.currentTrack,
    required this.isVideoMode,
    required this.isVideoLoading,
    required this.onLyricsTapped,
    required this.onQueueTapped,
    required this.onVideoTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildFavoritePill(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStudioPill(
                  label: isVideoLoading ? 'Chargement...' : (isVideoMode ? 'Mode Audio' : 'Voir le clip'),
                  icon: isVideoMode ? Icons.headphones_rounded : Icons.play_circle_fill_rounded,
                  isFilledOrange: isVideoMode,
                  onTap: onVideoTapped,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStudioPill(
                  label: 'Paroles',
                  icon: Icons.lyrics_outlined,
                  isFilledOrange: false,
                  onTap: onLyricsTapped,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStudioPill(
                  label: 'File d’attente',
                  icon: Icons.queue_music_rounded,
                  isFilledOrange: false,
                  onTap: onQueueTapped,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDownloadPill(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritePill(BuildContext context) {
    return BlocBuilder<SuperlikeCubit, SuperlikeState>(
      builder: (context, slState) {
        final isSuper = slState.isSuperliked(currentTrack.id);
        return BlocBuilder<LibraryCubit, LibraryState>(
          builder: (context, _) {
            final isFav = context.read<LibraryCubit>().isFavorite(
                  currentTrack.id,
                  title: currentTrack.title,
                  artist: currentTrack.artistName,
                );
            final bool isActive = isSuper || isFav;

            return _buildStudioPill(
              label: isSuper ? 'Superliké' : (isFav ? 'Dans vos favoris' : 'J’aime ce son'),
              icon: isSuper ? Icons.local_fire_department_rounded : (isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded),
              isFilledOrange: isActive,
              onTap: () {
                HapticFeedback.lightImpact();
                final cubit = context.read<LibraryCubit>();
                if (isFav) {
                  cubit.removeFavorite(currentTrack.id);
                } else {
                  cubit.addFavorite(currentTrack);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDownloadPill(BuildContext context) {
    return BlocBuilder<DownloadCubit, DownloadState>(
      builder: (context, downloadState) {
        bool isDownloaded = false;
        bool isDownloading = false;
        double progress = 0.0;

        if (downloadState is DownloadStateData) {
          isDownloaded = downloadState.downloadedIds.contains(currentTrack.id);
          if (downloadState.downloadingProgress.containsKey(currentTrack.id)) {
            isDownloading = true;
            progress = downloadState.downloadingProgress[currentTrack.id]!;
          }
        }

        if (isDownloading) {
          final pct = (progress * 100).clamp(0, 99).toInt();
          return _buildStudioPill(
            label: '$pct%',
            icon: Icons.downloading_rounded,
            isFilledOrange: true,
            onTap: () {},
          );
        }

        return _buildStudioPill(
          label: isDownloaded ? 'Téléchargé' : 'Hors-ligne',
          icon: isDownloaded ? Icons.verified_rounded : Icons.download_outlined,
          isFilledOrange: isDownloaded,
          onTap: () {
            if (isDownloaded) {
              context.read<DownloadCubit>().removeDownload(currentTrack.id);
            } else {
              context.read<DownloadCubit>().downloadTrack(currentTrack);
            }
          },
        );
      },
    );
  }

  Widget _buildStudioPill({
    required String label,
    required IconData icon,
    required bool isFilledOrange,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isFilledOrange ? AppColors.primary : const Color(0xFF2B180C).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFilledOrange ? AppColors.primary : const Color(0xFF6D3B1A).withValues(alpha: 0.55),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isFilledOrange ? Colors.white : const Color(0xFFD7996E),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isFilledOrange ? Colors.white : const Color(0xFFD7996E),
                  fontSize: 12,
                  fontWeight: isFilledOrange ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// 7. VAGUES LUMINEUSES SOIE ORANGE (pour arrière-plan décoratif optionnel)
/// ============================================================================
class SpecialBottomSilkWaves extends StatefulWidget {
  final bool isPlaying;

  const SpecialBottomSilkWaves({
    super.key,
    required this.isPlaying,
  });

  @override
  State<SpecialBottomSilkWaves> createState() => _SpecialBottomSilkWavesState();
}

class _SpecialBottomSilkWavesState extends State<SpecialBottomSilkWaves>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    if (widget.isPlaying) {
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SpecialBottomSilkWaves oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_waveController.isAnimating) {
      _waveController.repeat();
    } else if (!widget.isPlaying && _waveController.isAnimating) {
      _waveController.stop();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, _) {
          return CustomPaint(
            size: const Size(double.infinity, 82),
            painter: _SilkWavesPainter(
              phase: _waveController.value * math.pi * 2,
            ),
          );
        },
      ),
    );
  }
}

class _SilkWavesPainter extends CustomPainter {
  final double phase;

  _SilkWavesPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bottomGlow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.34),
          AppColors.primary.withValues(alpha: 0.10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bottomGlow);

    _drawRibbonWave(
      canvas: canvas,
      size: size,
      amplitude: h * 0.30,
      frequency: 1.8,
      phaseShift: phase,
      verticalCenter: h * 0.56,
      strokeColor: AppColors.primary.withValues(alpha: 0.90),
      fillAlpha: 0.18,
      strokeWidth: 2.2,
    );

    _drawRibbonWave(
      canvas: canvas,
      size: size,
      amplitude: h * 0.24,
      frequency: 2.3,
      phaseShift: -phase * 0.8 + 1.2,
      verticalCenter: h * 0.64,
      strokeColor: const Color(0xFFFFB74D).withValues(alpha: 0.70),
      fillAlpha: 0.12,
      strokeWidth: 1.6,
    );
  }

  void _drawRibbonWave({
    required Canvas canvas,
    required Size size,
    required double amplitude,
    required double frequency,
    required double phaseShift,
    required double verticalCenter,
    required Color strokeColor,
    required double fillAlpha,
    required double strokeWidth,
  }) {
    final w = size.width;
    final h = size.height;
    final linePath = Path();
    final fillPath = Path();

    const int steps = 48;
    for (int i = 0; i <= steps; i++) {
      final double t = i / steps;
      final double x = t * w;
      final double y = verticalCenter +
          math.sin(t * math.pi * frequency + phaseShift) * amplitude *
              math.sin(t * math.pi);
      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, h);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(w, h);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: fillAlpha),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);

    final glowStroke = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(linePath, glowStroke);

    final mainStroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, mainStroke);
  }

  @override
  bool shouldRepaint(covariant _SilkWavesPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
