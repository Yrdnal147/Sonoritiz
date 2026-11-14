import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/player/presentation/cubit/player_cubit.dart';
import '../../features/player/presentation/cubit/player_state.dart';
import '../../features/player/presentation/cubit/superlike_cubit.dart';
import '../../features/player/presentation/cubit/superlike_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'sonoritiz_artwork.dart';
import 'artist_name_display.dart';
import 'playing_indicator_overlay.dart';
import 'superlike_torch_badge.dart';

class SonoritizTrackCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double width;
  final String? tag; // Pour le Hero animation
  final String? trackId;
  final int? rank;
  final bool showCenterLogo;

  const SonoritizTrackCard({
    Key? key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.width = 140.0,
    this.tag,
    this.trackId,
    this.rank,
    this.showCenterLogo = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget artwork = SonoritizArtwork(
      imageUrl: imageUrl,
      width: width,
      height: width,
      borderRadius: AppDimensions.radiusMd,
    );

    if (tag != null) {
      artwork = Hero(tag: tag!, child: artwork);
    }

    return BlocSelector<PlayerCubit, PlayerState, bool>(
      selector: (state) => trackId != null && state.currentTrack?.id == trackId,
      builder: (context, isCurrentTrack) {
        if (trackId != null) {
          artwork = PlayingIndicatorOverlay(trackId: trackId!, child: artwork);
        }

        Widget artworkWithBadge = artwork;
        final List<Widget> overlayWidgets = [];

        if (trackId != null) {
          overlayWidgets.add(
            Positioned(
              top: 6,
              right: 6,
              child: BlocBuilder<SuperlikeCubit, SuperlikeState>(
                builder: (context, state) {
                  if (!state.isSuperliked(trackId!)) return const SizedBox.shrink();
                  return const SuperlikeTorchBadge(
                    size: TorchBadgeSize.small,
                    showBackground: true,
                  );
                },
              ),
            ),
          );
        }

        if (rank != null) {
          overlayWidgets.add(
            Positioned(
              top: 6,
              left: 6,
              child: _buildRankBadge(rank!),
            ),
          );
        }

        if (showCenterLogo) {
          overlayWidgets.add(
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: width * 0.34,
                    height: width * 0.34,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      shape: BoxShape.circle,
                    ),
                    child: Opacity(
                      opacity: 0.88,
                      child: Image.asset(
                        'assets/images/logo_transparent.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        if (overlayWidgets.isNotEmpty) {
          artworkWithBadge = Stack(
            children: [
              artwork,
              ...overlayWidgets,
            ],
          );
        }

        return Semantics(
          button: true,
          label: "Jouer $title par $subtitle",
          child: GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  artworkWithBadge,
                  const SizedBox(height: AppDimensions.spacingSm),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      color: isCurrentTrack ? AppColors.primary : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  ArtistNameDisplay(
                    artistName: subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: isCurrentTrack ? AppColors.primary.withOpacity(0.8) : Colors.white.withOpacity(0.7),
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

  Widget _buildRankBadge(int rank) {
    Gradient gradient;
    Color textColor = Colors.white;
    Color borderColor = Colors.white24;
    IconData? icon;

    if (rank == 1) {
      gradient = const LinearGradient(
        colors: [Color(0xFFFFDF00), Color(0xFFD4AF37), Color(0xFFFFA000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      textColor = const Color(0xFF1A1A1A);
      borderColor = const Color(0xFFFFE082);
      icon = Icons.emoji_events_rounded;
    } else if (rank == 2) {
      gradient = const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFE0E0E0), Color(0xFF9E9E9E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      textColor = const Color(0xFF1A1A1A);
      borderColor = Colors.white70;
    } else if (rank == 3) {
      gradient = const LinearGradient(
        colors: [Color(0xFFFF9F43), Color(0xFFFA7921), Color(0xFFD35400)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      textColor = const Color(0xFF1A1A1A);
      borderColor = const Color(0xFFFFB74D);
    } else {
      gradient = LinearGradient(
        colors: [
          Colors.black.withOpacity(0.85),
          Colors.black.withOpacity(0.65),
        ],
      );
      textColor = Colors.white;
      borderColor = Colors.white.withOpacity(0.2);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: textColor),
            const SizedBox(width: 2),
          ],
          Text(
            "#$rank",
            style: TextStyle(
              color: textColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
