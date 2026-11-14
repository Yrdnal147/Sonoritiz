import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/widgets/sonoritiz_icon_button.dart';
import '../../../../offline/presentation/cubit/download_cubit.dart';
import '../../../data/models/track_model.dart';


class PlayerSecondaryControls extends StatelessWidget {
  final TrackModel currentTrack;
  final VoidCallback onQueueTapped;
  final VoidCallback onLyricsTapped;
  final VoidCallback onDownloadTapped;
  final VoidCallback? onKaraokeTapped;

  const PlayerSecondaryControls({
    Key? key,
    required this.currentTrack,
    required this.onQueueTapped,
    required this.onLyricsTapped,
    required this.onDownloadTapped,
    this.onKaraokeTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingXxl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SonoritizIconButton(
            icon: Icons.lyrics_outlined,
            tooltip: "Paroles",
            color: Colors.white,
            onPressed: onLyricsTapped,
          ),
          if (onKaraokeTapped != null)
            SonoritizIconButton(
              icon: Icons.celebration_rounded,
              tooltip: "Mode Party / Karaoké",
              color: Colors.white,
              onPressed: onKaraokeTapped!,
            ),
          SonoritizIconButton(
            icon: Icons.queue_music_rounded,
            tooltip: "File d'attente",
            color: Colors.white,
            onPressed: onQueueTapped,
          ),
          BlocBuilder<DownloadCubit, DownloadState>(
            builder: (context, downloadState) {
              bool isDownloaded = false;
              bool isDownloading = false;
              double progress = 0.0;
              
              if (downloadState is DownloadStateData) {
                isDownloaded = downloadState.downloadedIds.contains(currentTrack.id);
                if (downloadState.downloadingProgress.containsKey(currentTrack.id)) {
                  isDownloading = true;
                  progress = downloadState.downloadingProgress[currentTrack.id]!;
                }
              }

              if (isDownloading) {
                return Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingSm),
                  child: SizedBox(
                    width: AppDimensions.iconMd, 
                    height: AppDimensions.iconMd,
                    child: CircularProgressIndicator(
                      value: progress, 
                      color: colorScheme.primary, 
                      strokeWidth: 3
                    ),
                  ),
                );
              }

              return SonoritizIconButton(
                icon: isDownloaded ? Icons.download_done : Icons.download_outlined,
                tooltip: isDownloaded ? "Téléchargé" : "Télécharger",
                color: isDownloaded ? colorScheme.primary : Colors.white,
                onPressed: () {
                  if (isDownloaded) {
                    context.read<DownloadCubit>().removeDownload(currentTrack.id);
                  } else {
                    context.read<DownloadCubit>().downloadTrack(currentTrack);
                  }
                  onDownloadTapped();
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
