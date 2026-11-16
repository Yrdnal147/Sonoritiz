import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../features/player/data/models/track_model.dart';
import '../../../features/player/presentation/cubit/player_cubit.dart';
import '../../../core/theme/app_dimensions.dart';
import '../utils/responsive_utils.dart';
import '../../../features/library/presentation/cubit/library_ui_cubit.dart';
import 'track_context_menu.dart';
import 'artist_name_display.dart';
import 'sonoritiz_artwork.dart';
import 'sonoritiz_track_tile.dart';
import 'sonoritiz_icon_button.dart';

class TrackGridView extends StatelessWidget {
  final List<TrackModel> tracks;
  final ViewMode viewMode;
  final SortMode sortMode;
  final Map<String, String>? localCoverPaths;
  final bool isSelectionMode;
  final Set<String> selectedTrackIds;
  final Function(String trackId, bool selected)? onSelectionChanged;
  final String? playbackSource;

  const TrackGridView({
    Key? key,
    required this.tracks,
    required this.viewMode,
    required this.sortMode,
    this.localCoverPaths,
    this.isSelectionMode = false,
    this.selectedTrackIds = const {},
    this.onSelectionChanged,
    this.playbackSource,
  }) : super(key: key);

  static List<TrackModel> sortTracks(List<TrackModel> tracks, SortMode sortMode) {
    if (sortMode == SortMode.recent) {
      return List<TrackModel>.from(tracks);
    }
    final sorted = List<TrackModel>.from(tracks);
    sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final sortedTracks = sortTracks(tracks, sortMode);

    if (viewMode == ViewMode.list) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final track = sortedTracks[index];
            final localPath = localCoverPaths?[track.id];
            final cover = (localPath != null &&
                    localPath.isNotEmpty &&
                    File(localPath).existsSync())
                ? "file://$localPath"
                : track.coverUrl;

            return SonoritizTrackTile(
              track: track,
              coverOverride: cover,
              queue: sortedTracks,
              playbackSource: playbackSource,
              onTap: isSelectionMode
                  ? null
                  : () => context.read<PlayerCubit>().playTrack(
                        track,
                        queue: sortedTracks,
                        source: playbackSource,
                      ),
              isSelectionMode: isSelectionMode,
              isSelected: selectedTrackIds.contains(track.id),
              onSelectionChanged: (selected) =>
                  onSelectionChanged?.call(track.id, selected ?? false),
              trailing: isSelectionMode
                  ? null
                  : SonoritizIconButton(
                      icon: Icons.more_horiz_rounded,
                      tooltip: "Options",
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      onPressed: () => TrackContextMenu.show(context, track),
                    ),
            );
          },
          childCount: sortedTracks.length,
        ),
      );
    }

    if (viewMode == ViewMode.listCompact) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final track = sortedTracks[index];
            final isSelected = selectedTrackIds.contains(track.id);

            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: AppDimensions.spacingLg),
              leading: Text(
                '${index + 1}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              title: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                track.artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              trailing: isSelectionMode
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (v) =>
                          onSelectionChanged?.call(track.id, v ?? false),
                    )
                  : IconButton(
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      onPressed: () => TrackContextMenu.show(context, track),
                    ),
              onTap: isSelectionMode
                  ? () => onSelectionChanged?.call(track.id, !isSelected)
                  : () => context.read<PlayerCubit>().playTrack(
                        track,
                        queue: sortedTracks,
                        source: playbackSource,
                      ),
              onLongPress: isSelectionMode
                  ? null
                  : (onSelectionChanged != null
                      ? () => onSelectionChanged!.call(track.id, true)
                      : () => TrackContextMenu.show(context, track)),
            );
          },
          childCount: sortedTracks.length,
        ),
      );
    }

    final double width = MediaQuery.sizeOf(context).width;
    final int baseCols = ResponsiveUtils.adaptiveGridColumns(
      width,
      narrow: 2,
      mobile: 2,
      medium: 3,
      expanded: 4,
      ultraWide: 5,
    );

    int crossAxisCount;
    double childAspectRatio;
    switch (viewMode) {
      case ViewMode.gridSmall:
        crossAxisCount = width < 350 ? 2 : (baseCols + 1);
        childAspectRatio = 0.75;
        break;
      case ViewMode.gridMedium:
        crossAxisCount = baseCols;
        childAspectRatio = 0.8;
        break;
      case ViewMode.gridLarge:
        crossAxisCount = width >= 900 ? 3 : (width >= 600 ? 2 : 1);
        childAspectRatio = 1.0;
        break;
      case ViewMode.cards:
        crossAxisCount = width >= 900 ? 3 : (width >= 600 ? 2 : 1);
        childAspectRatio = 0.85;
        break;
      default:
        crossAxisCount = baseCols;
        childAspectRatio = 0.8;
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: AppDimensions.spacingMd,
          mainAxisSpacing: AppDimensions.spacingMd,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) =>
              _buildGridItem(context, sortedTracks[index], sortedTracks, viewMode),
          childCount: sortedTracks.length,
        ),
      ),
    );
  }

  Widget _buildGridItem(
    BuildContext context,
    TrackModel track,
    List<TrackModel> queue,
    ViewMode mode,
  ) {
    final localPath = localCoverPaths?[track.id];
    final cover = (localPath != null &&
            localPath.isNotEmpty &&
            File(localPath).existsSync())
        ? "file://$localPath"
        : track.coverUrl;
    final textTheme = Theme.of(context).textTheme;
    final isSelected = selectedTrackIds.contains(track.id);

    return Semantics(
      button: true,
      label: "Jouer ${track.title}",
      child: GestureDetector(
        onTap: isSelectionMode
            ? () => onSelectionChanged?.call(track.id, !isSelected)
            : () => context
                .read<PlayerCubit>()
                .playTrack(track, queue: queue, source: playbackSource),
        onLongPress: isSelectionMode
            ? null
            : (onSelectionChanged != null
                ? () => onSelectionChanged!.call(track.id, true)
                : () => TrackContextMenu.show(context, track)),
        child: Container(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    SonoritizArtwork(
                      imageUrl: cover,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: AppDimensions.radiusMd,
                      cacheMaxDimension: 500,
                    ),
                    if (isSelectionMode)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (val) =>
                                onSelectionChanged?.call(track.id, val ?? false),
                            activeColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    ArtistNameDisplay(
                      artistName: track.artistName,
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
