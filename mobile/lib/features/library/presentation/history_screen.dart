import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_dimensions.dart';
import '../data/repositories/library_repository.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../../core/utils/share_utils.dart';
import '../../../core/widgets/sonoritiz_track_tile.dart';
import '../../../core/widgets/sonoritiz_icon_button.dart';

class HistoryScreen extends StatelessWidget {
  final List<HistoryModel> history;

  const HistoryScreen({Key? key, required this.history}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              "Ton historique d'écoute apparaîtra ici",
              style: textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingSm),
        physics: const BouncingScrollPhysics(),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final item = history[index];
          final track = item.track;
          if (track == null) return const SizedBox.shrink();

          return SonoritizTrackTile(
            imageUrl: track.coverUrl,
            title: track.title,
            subtitle: track.artistName,
            onTap: () {
              context.read<PlayerCubit>().playTrack(track);
            },
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz_rounded, color: colorScheme.onSurfaceVariant),
              color: colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
              onSelected: (value) {
                if (value == 'share') {
                  ShareUtils.shareTrack(track);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_rounded, color: colorScheme.onSurface, size: AppDimensions.iconSm),
                      const SizedBox(width: AppDimensions.spacingMd),
                      Text("Partager", style: TextStyle(color: colorScheme.onSurface)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
