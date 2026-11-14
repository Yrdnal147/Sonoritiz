import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sonoritiz_cover_atmosphere.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import '../../../core/widgets/superlike_torch_badge.dart';
import '../../../core/widgets/track_grid_view.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../player/presentation/cubit/superlike_cubit.dart';
import '../../player/presentation/cubit/superlike_state.dart';
import 'cubit/library_ui_cubit.dart';

class SuperlikedTracksScreen extends StatelessWidget {
  const SuperlikedTracksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SuperlikeCubit, SuperlikeState>(
      builder: (context, superState) {
        final tracks = superState.tracks;
        final heroCover = tracks.isNotEmpty ? tracks.first.coverUrl : '';

        return Scaffold(
          backgroundColor: Colors.black,
          body: SonoritizCoverAtmosphere(
            coverUrl: heroCover,
            accentFallback: const Color(0xFFFF6D00),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => context.pop(),
                    ),
                    title: const SonoritizPageTitle(
                      title: 'Sonoritiz Superlikés',
                      fontSize: 21,
                    ),
                  ),
                  Expanded(
                    child: tracks.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 36),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SuperlikeTorchBadge(
                                    size: TorchBadgeSize.large,
                                    animateGlow: true,
                                  ),
                                  const SizedBox(height: 18),
                                  const Text(
                                    "Aucun Superlike pour l'instant",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Superlike jusqu'à ${SuperlikeCubit.maxSuperlikes} morceaux exceptionnels depuis le lecteur ou le menu d'un titre.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 13.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                                  child: Row(
                                    children: [
                                      const SuperlikeTorchBadge(
                                        size: TorchBadgeSize.small,
                                        showBackground: false,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "${tracks.length} / ${SuperlikeCubit.maxSuperlikes} titres d'élite",
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.72),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: () {
                                          final shuffled = List<TrackModel>.from(tracks)..shuffle();
                                          context.read<PlayerCubit>().playTrack(
                                                shuffled.first,
                                                queue: shuffled,
                                                source: 'vos Sonoritiz Superlikés',
                                              );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(24),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.16),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.shuffle_rounded, color: Colors.white, size: 18),
                                              SizedBox(width: 6),
                                              Text(
                                                "Aléatoire",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          context.read<PlayerCubit>().playTrack(
                                                tracks.first,
                                                queue: tracks,
                                                source: 'vos Sonoritiz Superlikés',
                                              );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                                              SizedBox(width: 4),
                                              Text(
                                                "Lire",
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              TrackGridView(
                                tracks: tracks,
                                viewMode: ViewMode.list,
                                sortMode: SortMode.recent,
                                playbackSource: 'vos Sonoritiz Superlikés',
                              ),
                              const SliverToBoxAdapter(child: SizedBox(height: 130)),
                            ],
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
