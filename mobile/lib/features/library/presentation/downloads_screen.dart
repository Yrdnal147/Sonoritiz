import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_animations.dart';
import '../../offline/presentation/cubit/download_cubit.dart';
import '../../offline/presentation/cubit/download_state.dart';
import '../../../core/widgets/track_grid_view.dart';
import 'cubit/library_ui_cubit.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<DownloadCubit, DownloadState>(
      builder: (context, state) {
        if (state is! DownloadStateData) {
          return const Center(child: CircularProgressIndicator());
        }

        final offlineTracks = state.offlineTracks;
        final downloading = state.downloadingProgress;

        if (offlineTracks.isEmpty && downloading.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download_done_rounded, size: 80, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                const SizedBox(height: AppDimensions.spacingMd),
                Text(
                  "Aucun téléchargement",
                  style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ).animate().fadeIn().scale(duration: AppAnimations.normal),
          );
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            if (downloading.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppDimensions.spacingLg, AppDimensions.spacingXl, AppDimensions.spacingLg, AppDimensions.spacingMd),
                sliver: SliverToBoxAdapter(
                  child: Text("Téléchargements en cours", style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))
                      .animate().fadeIn(),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final trackId = downloading.keys.elementAt(index);
                    final progress = downloading[trackId] ?? 0.0;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingLg, vertical: AppDimensions.spacingSm),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      title: Text("Téléchargement...", style: textTheme.titleSmall),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppDimensions.spacingSm),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 4),
                          Text("${(progress * 100).toStringAsFixed(0)}%", style: textTheme.bodySmall),
                        ],
                      ),
                    ).animate().fadeIn();
                  },
                  childCount: downloading.length,
                ),
              ),
            ],

            if (offlineTracks.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppDimensions.spacingLg, AppDimensions.spacingXl, AppDimensions.spacingLg, AppDimensions.spacingMd),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Sons téléchargés", style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text("${offlineTracks.length} titres", style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                    ],
                  ).animate().fadeIn(),
                ),
              ),
              BlocBuilder<LibraryUiCubit, LibraryUiState>(
                builder: (context, uiState) {
                  final Map<String, String> localCoverPaths = {
                    for (var ot in offlineTracks) ot.track.id: ot.localCoverPath
                  };
                  return TrackGridView(
                    tracks: offlineTracks.map((e) => e.track).toList(),
                    viewMode: uiState.getViewModeFor('downloads'),
                    sortMode: uiState.getSortModeFor('downloads'),
                    localCoverPaths: localCoverPaths,
                  );
                },
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)), 
          ],
        );
      },
    );
  }
}
