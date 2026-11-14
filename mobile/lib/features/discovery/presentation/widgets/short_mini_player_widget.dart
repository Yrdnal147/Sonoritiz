import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/artist_name_display.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../../features/player/data/models/track_model.dart';
import '../../../../features/player/presentation/cubit/player_cubit.dart';

/// Carte dock flottante inspirée fidèlement du Lecteur Signature Sonoritiz.
/// Intègre verre dépoli néo-noir, liseré chromatique solaire, vibration acoustique
/// animée et typographie signature.
class ShortMiniPlayerWidget extends StatelessWidget {
  final TrackModel track;
  final bool isPlaying;
  final double progress; // 0.0 à 1.0 (court extrait de 20s)
  final VoidCallback onPlayPause;
  final VoidCallback onOpenFullPlayer;
  final Color progressColor;

  const ShortMiniPlayerWidget({
    Key? key,
    required this.track,
    required this.isPlaying,
    required this.progress,
    required this.onPlayPause,
    required this.onOpenFullPlayer,
    required this.progressColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color accent = progressColor == Colors.transparent ? AppColors.primary : progressColor;

    return GestureDetector(
      onTap: () {
        onOpenFullPlayer();
        context.read<PlayerCubit>().playTrack(track);
        context.push('/fullscreen');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            // Halo d'ambiance signature
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
            // Ombre portée profonde
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.75),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1C1717),
                    Color(0xFF100E10),
                  ],
                ),
                border: Border.all(
                  color: accent.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Miniature de pochette avec halo
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: SonoritizArtwork(
                            imageUrl: track.coverUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Infos du morceau avec gestion des featurings
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            ArtistNameDisplay(
                              artistName: track.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: accent,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Micro-visualiseur signature acoustique (onde vibrante)
                      _buildSignatureVisualizer(accent),
                      const SizedBox(width: 10),

                      // Bouton Lecture / Pause sculpté
                      GestureDetector(
                        onTap: onPlayPause,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent,
                                accent.withValues(alpha: 0.85),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Barre de progression fine avec jauge dynamique 20s
                  Stack(
                    children: [
                      Container(
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          height: 3.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accent.withValues(alpha: 0.7),
                                accent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.6),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Barre d'ondes acoustiques miniatures inspirée de SpecialWaveformRow
  Widget _buildSignatureVisualizer(Color accentColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final heights = [10.0, 18.0, 14.0, 8.0];
        final currentHeight = isPlaying ? heights[index] : 4.0;
        return AnimatedContainer(
          duration: Duration(milliseconds: 200 + (index * 50)),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 3,
          height: currentHeight,
          decoration: BoxDecoration(
            color: isPlaying ? accentColor : Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
