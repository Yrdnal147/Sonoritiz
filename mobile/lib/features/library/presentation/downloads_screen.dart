import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../offline/presentation/cubit/download_cubit.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../../core/widgets/track_grid_view.dart';
import 'cubit/library_ui_cubit.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadCubit, DownloadState>(
      builder: (context, state) {
        if (state is! DownloadStateData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final offlineTracks = state.offlineTracks;
        final downloading = state.downloadingProgress;

        if (offlineTracks.isEmpty && downloading.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download_done, size: 80, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text(
                  "Aucun téléchargement",
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18),
                ),
              ],
            ).animate().fadeIn().scale(),
          );
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Section 1: Téléchargements en cours
            if (downloading.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: const Text("Téléchargements en cours", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
                      .animate().fadeIn(),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final trackId = downloading.keys.elementAt(index);
                    final progress = downloading[trackId] ?? 0.0;
                    // On affiche juste un indicateur pour l'instant car on n'a pas le TrackModel complet dans downloadingProgress,
                    // mais si on l'a (ce qui n'est pas le cas dans le Map<String, double>), on pourrait afficher le titre.
                    // On va juste afficher l'ID en attendant ou "Téléchargement..."
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
                        child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      ),
                      title: const Text("Téléchargement...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 4),
                          Text("${(progress * 100).toStringAsFixed(0)}%", style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ).animate().fadeIn();
                  },
                  childCount: downloading.length,
                ),
              ),
            ],

            // Section 2: Sons téléchargés
            if (offlineTracks.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Sons téléchargés", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("${offlineTracks.length} titres", style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
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
                    viewMode: uiState.viewMode,
                    sortMode: uiState.sortMode,
                    localCoverPaths: localCoverPaths,
                  );
                },
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)), // Espace en bas
          ],
        );
      },
    );
  }
}
