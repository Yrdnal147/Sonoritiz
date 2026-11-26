import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/widgets/track_grid_view.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../data/repositories/library_repository.dart';
import 'cubit/library_ui_cubit.dart';

class HistoryScreen extends StatelessWidget {
  final List<HistoryModel> history;

  const HistoryScreen({Key? key, required this.history}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 38),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 42,
                  color: AppColors.primary,
                ),
              ).animate().scale(
                    delay: AppAnimations.normal,
                    duration: AppAnimations.slow,
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 20),
              Text(
                "Aucun historique",
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ).animate().fadeIn(delay: AppAnimations.slow),
              const SizedBox(height: 8),
              Text(
                "Les titres que tu écoutes apparaîtront automatiquement ici.",
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ).animate().fadeIn(delay: AppAnimations.slow),
              const SizedBox(height: 26),
              GestureDetector(
                onTap: () => context.go('/home'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.explore_rounded,
                        color: Colors.black,
                        size: 19,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Explorer la musique",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: AppAnimations.slow),
            ],
          ),
        ),
      );
    }

    final validTracks =
        history.map((e) => e.track).whereType<TrackModel>().toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlocBuilder<LibraryUiCubit, LibraryUiState>(
        builder: (context, uiState) {
          final viewMode = uiState.getViewModeFor('history');
          final sortMode = uiState.getSortModeFor('history');

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              if (validTracks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14141B),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Écoutes récentes",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${validTracks.length} ${validTracks.length > 1 ? "titres joués" : "titre joué"}',
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.56),
                                    fontSize: 12.2,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              final shuffled =
                                  List<TrackModel>.from(validTracks)..shuffle();
                              context.read<PlayerCubit>().playTrack(
                                    shuffled.first,
                                    queue: shuffled,
                                    source: "votre historique",
                                  );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.14),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.shuffle_rounded,
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    "Aléatoire",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
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
                                    validTracks.first,
                                    queue: validTracks,
                                    source: "votre historique",
                                  );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 19,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "Lire",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 13.5,
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
                ),
                TrackGridView(
                  key: ValueKey('history_${viewMode.name}_${sortMode.name}'),
                  tracks: validTracks,
                  viewMode: viewMode,
                  sortMode: sortMode,
                  playbackSource: "votre historique",
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
    );
  }
}
