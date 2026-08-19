import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import '../../../features/player/data/models/track_model.dart';
import '../../../features/player/presentation/cubit/player_cubit.dart';
import '../../../core/theme/app_dimensions.dart';
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
      return List.from(tracks);
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
          (context, index) {
            final track = sortedTracks[index];
            final localPath = localCoverPaths?[track.id];
            final cover = (localPath != null && localPath.isNotEmpty && File(localPath).existsSync()) ? "file://$localPath" : track.coverUrl;
            
            return SonoritizTrackTile(
              imageUrl: cover,
              title: track.title,
              subtitle: track.artistName,
              onTap: () => context.read<PlayerCubit>().playTrack(track, queue: sortedTracks),
              trailing: SonoritizIconButton(
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
        childAspectRatio = 1.0;
        break;
      default:
        crossAxisCount = 2;
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
          (context, index) => _buildGridItem(context, sortedTracks[index], sortedTracks, viewMode),
          childCount: sortedTracks.length,
        ),
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, TrackModel track, List<TrackModel> queue, ViewMode mode) {
    final localPath = localCoverPaths?[track.id];
    final cover = (localPath != null && localPath.isNotEmpty && File(localPath).existsSync()) ? "file://$localPath" : track.coverUrl;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: "Jouer ${track.title}",
      child: GestureDetector(
        onTap: () => context.read<PlayerCubit>().playTrack(track, queue: queue),
        onLongPress: () => TrackContextMenu.show(context, track),
        child: Container(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SonoritizArtwork(
                  imageUrl: cover,
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: AppDimensions.radiusMd,
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
