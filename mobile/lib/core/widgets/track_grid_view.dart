import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import '../../../features/player/data/models/track_model.dart';
import '../../../features/player/presentation/cubit/player_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/library/presentation/cubit/library_ui_cubit.dart';
import 'track_context_menu.dart';

class TrackGridView extends StatelessWidget {
  final List<TrackModel> tracks;
  final ViewMode viewMode;
  final SortMode sortMode;
  final Map<String, String>? localCoverPaths; // For downloaded tracks

  const TrackGridView({
    Key? key,
    required this.tracks,
    required this.viewMode,
    required this.sortMode,
    this.localCoverPaths,
  }) : super(key: key);

  List<TrackModel> _getSortedTracks() {
    if (sortMode == SortMode.recent) {
      return List.from(tracks); // Assuming original list is recent-first
    } else {
      final sorted = List<TrackModel>.from(tracks);
      sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      return sorted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedTracks = _getSortedTracks();

    if (viewMode == ViewMode.list) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildListItem(context, sortedTracks[index], sortedTracks, index),
          childCount: sortedTracks.length,
        ),
      );
    }

    int crossAxisCount;
    double childAspectRatio;
    switch (viewMode) {
      case ViewMode.gridSmall:
        crossAxisCount = 3;
        childAspectRatio = 0.75;
        break;
      case ViewMode.gridMedium:
        crossAxisCount = 2;
        childAspectRatio = 0.8;
        break;
      case ViewMode.gridLarge:
        crossAxisCount = 1;
        childAspectRatio = 1.0; // Square
        break;
      default:
        crossAxisCount = 2;
        childAspectRatio = 0.8;
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildGridItem(context, sortedTracks[index], sortedTracks, index, viewMode),
          childCount: sortedTracks.length,
        ),
      ),
    );
  }

  Widget _buildCover(TrackModel track, double size, {double borderRadius = 8}) {
    final localPath = localCoverPaths?[track.id];
    
    if (track.coverUrl.startsWith("file://")) {
      final file = File(track.coverUrl.replaceFirst("file://", ""));
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: file.existsSync()
            ? Image.file(file, width: size, height: size, fit: BoxFit.cover)
            : _buildPlaceholder(size),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: localPath != null && localPath.isNotEmpty && File(localPath).existsSync()
          ? Image.file(File(localPath), width: size, height: size, fit: BoxFit.cover)
          : (track.coverUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: track.coverUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => _buildPlaceholder(size),
                )
              : _buildPlaceholder(size)),
    );
  }

  Widget _buildPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: AppColors.surface,
      child: const Icon(Icons.music_note, color: AppColors.textSecondary),
    );
  }

  Widget _buildListItem(BuildContext context, TrackModel track, List<TrackModel> queue, int index) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: _buildCover(track, 50),
      title: Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(track.artistName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert, color: Colors.white54),
        onPressed: () => TrackContextMenu.show(context, track),
      ),
      onTap: () => context.read<PlayerCubit>().playTrack(track, queue: queue),
    );
  }

  Widget _buildGridItem(BuildContext context, TrackModel track, List<TrackModel> queue, int index, ViewMode mode) {
    return GestureDetector(
      onTap: () => context.read<PlayerCubit>().playTrack(track, queue: queue),
      onLongPress: () => TrackContextMenu.show(context, track),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildCover(track, double.infinity, borderRadius: 0),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: mode == ViewMode.gridSmall ? 12 : 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artistName,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: mode == ViewMode.gridSmall ? 10 : 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
