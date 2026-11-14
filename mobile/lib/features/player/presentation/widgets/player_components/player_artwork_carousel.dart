import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import '../../../../../core/theme/app_decorations.dart' show AppDecorations;
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/widgets/sonoritiz_artwork.dart';
import '../../cubit/player_cubit.dart';
import '../../cubit/player_state.dart';
import '../../cubit/superlike_cubit.dart';
import '../../cubit/superlike_state.dart';
import '../../../../../core/widgets/superlike_torch_badge.dart';

class PlayerArtworkCarousel extends StatelessWidget {
  final PageController pageController;
  final double coverSize;
  final Color? dominantColor;
  final bool isVideoMode;
  final bool isVideoLoading;
  final VideoPlayerController? videoController;
  final Duration position;
  final Duration duration;

  const PlayerArtworkCarousel({
    Key? key,
    required this.pageController,
    required this.coverSize,
    this.dominantColor,
    required this.isVideoMode,
    required this.isVideoLoading,
    this.videoController,
    required this.position,
    required this.duration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerCubit, PlayerState>(
      builder: (context, state) {
        if (!state.hasTrack) return const SizedBox.shrink();

        return SizedBox(
          height: coverSize * 1.05 + 40,
          child: PageView.builder(
            controller: pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              final cubit = context.read<PlayerCubit>();
              if (index > state.currentIndex) {
                cubit.playNext();
              } else if (index < state.currentIndex) {
                cubit.playPrevious();
              }
            },
            itemCount: state.queue.length,
            itemBuilder: (context, index) {
              final qTrack = state.queue[index];
              final isCurrent = index == state.currentIndex;

              return AnimatedBuilder(
                animation: pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (pageController.position.haveDimensions) {
                    value = pageController.page! - index;
                    value = (1 - (value.abs() * 0.15)).clamp(0.0, 1.0);
                  } else if (!isCurrent) {
                    value = 0.85;
                  }
                  return Center(
                    child: Transform.scale(
                      scale: value,
                      child: child,
                    ),
                  );
                },
                child: CustomPaint(
                  foregroundPainter: isCurrent ? RectangularProgressPainter(
                    progress: duration.inMilliseconds > 0 
                        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0) 
                        : 0.0,
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 4.0,
                    borderRadius: AppDimensions.radiusXl + 8.0,
                  ) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.spacingXs),
                    child: isVideoMode && isCurrent
                        ? _buildVideoPlayer(context)
                        : _buildArtwork(context, qTrack.coverUrl, isCurrent, qTrack.id, index),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildVideoPlayer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      width: coverSize,
      height: coverSize * 1.05,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        color: Colors.black,
        boxShadow: AppDecorations.playerGlow(dominantColor ?? colorScheme.primary),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: isVideoLoading || videoController == null || !videoController!.value.isInitialized
            ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
            : FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: videoController!.value.size.width,
                  height: videoController!.value.size.height,
                  child: VideoPlayer(videoController!),
                ),
              ),
      ),
    );
  }

  Widget _buildArtwork(BuildContext context, String coverUrl, bool isCurrent, String trackId, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Hero(
      tag: 'cover_${trackId}_$index',
      child: Container(
        width: coverSize - 16,
        height: (coverSize - 16) * 1.05,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          boxShadow: isCurrent 
            ? AppDecorations.playerGlow(dominantColor ?? colorScheme.primary) 
            : AppDecorations.shadowLg(context),
        ),
        child: Stack(
          children: [
            SonoritizArtwork(
              imageUrl: coverUrl,
              width: coverSize - 16,
              height: (coverSize - 16) * 1.05,
              borderRadius: AppDimensions.radiusXl,
            ),
            BlocSelector<SuperlikeCubit, SuperlikeState, bool>(
              selector: (state) => state.isSuperliked(trackId),
              builder: (context, isSuper) {
                if (!isSuper) return const SizedBox.shrink();
                return const Positioned(
                  top: 12,
                  left: 12,
                  child: SuperlikeTorchBadge(
                    size: TorchBadgeSize.medium,
                    showBackground: true,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RectangularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final double borderRadius;

  RectangularProgressPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 4.0,
    this.borderRadius = 32.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0) return;

    final rect = Rect.fromLTWH(
      strokeWidth / 2, 
      strokeWidth / 2, 
      size.width - strokeWidth, 
      size.height - strokeWidth
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final path = Path()..addRRect(rrect);
    
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawPath(path, trackPaint);

    if (progress > 0) {
      final pathMetrics = path.computeMetrics().toList();
      if (pathMetrics.isNotEmpty) {
        final metric = pathMetrics.first;
        final extractPath = metric.extractPath(0.0, metric.length * progress);
        
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

        canvas.drawPath(extractPath, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RectangularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
