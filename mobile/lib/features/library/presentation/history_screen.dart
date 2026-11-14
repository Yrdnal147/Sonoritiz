import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_animations.dart';
import '../data/repositories/library_repository.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../player/data/models/track_model.dart';
import 'cubit/library_ui_cubit.dart';
import '../../../core/widgets/track_grid_view.dart';
import 'package:go_router/go_router.dart';

class HistoryScreen extends StatelessWidget {
  final List<HistoryModel> history;

  const HistoryScreen({Key? key, required this.history}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.history_rounded, size: 46, color: colorScheme.primary.withOpacity(0.7)),
              ).animate().scale(delay: AppAnimations.normal, duration: AppAnimations.slow, curve: Curves.easeOutBack),
              const SizedBox(height: 20),
              Text(
                "Aucun historique",
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ).animate().fadeIn(delay: AppAnimations.slow),
              const SizedBox(height: 8),
              Text(
                "Les titres que tu écoutes apparaîtront ici.",
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ).animate().fadeIn(delay: AppAnimations.slow),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.explore_rounded),
                label: const Text("Explorer la musique"),
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ).animate().fadeIn(delay: AppAnimations.slow),
            ],
          ),
        ),
      );
    }

    final validTracks = history.map((e) => e.track).whereType<TrackModel>().toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlocBuilder<LibraryUiCubit, LibraryUiState>(
        builder: (context, uiState) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              if (validTracks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        Text(
                          '${validTracks.length} ${validTracks.length > 1 ? "écoutes récentes" : "écoute récente"}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            final shuffled = List<TrackModel>.from(validTracks)..shuffle();
                            context.read<PlayerCubit>().playTrack(shuffled.first, queue: shuffled);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                                Icon(Icons.shuffle_rounded, color: Colors.white, size: 19),
                                SizedBox(width: 6),
                                Text(
                                  "Aléatoire",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            context.read<PlayerCubit>().playTrack(validTracks.first, queue: validTracks);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow_rounded, color: Colors.black, size: 21),
                                SizedBox(width: 4),
                                Text(
                                  "Lire",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14.5,
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
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: CustomScrollView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      slivers: [
                        TrackGridView(
                          key: ValueKey(uiState.getViewModeFor('history')),
                          tracks: validTracks,
                          viewMode: uiState.getViewModeFor('history'),
                          sortMode: uiState.getSortModeFor('history'),
                        ),
                      ],
                    ),
                  ),
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
