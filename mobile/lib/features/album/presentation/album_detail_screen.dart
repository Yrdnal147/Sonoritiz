import 'package:flutter/material.dart';
import '../../../core/widgets/sonoritiz_cover_atmosphere.dart';
import '../../player/data/models/track_model.dart';

class AlbumDetailScreen extends StatelessWidget {
  final String albumTitle;
  final String artistName;
  final String coverUrl;
  final List<TrackModel> tracks;

  const AlbumDetailScreen({
    super.key,
    required this.albumTitle,
    required this.artistName,
    required this.coverUrl,
    this.tracks = const [],
  });

  String _formatTotalDuration() {
    final totalSecs =
        tracks.fold<int>(0, (sum, t) => sum + t.durationSeconds);
    final mins = totalSecs ~/ 60;
    if (mins >= 60) {
      final h = mins ~/ 60;
      final m = mins % 60;
      return '${h}h ${m}min';
    }
    return '$mins min';
  }

  @override
  Widget build(BuildContext context) {
    final trackCountLabel =
        '${tracks.length} ${tracks.length > 1 ? "titres" : "titre"}';
    final durationLabel = tracks.isNotEmpty ? ' • ${_formatTotalDuration()}' : '';

    return SonoritizCollectionScaffold(
      title: albumTitle,
      badgeLabel: 'ALBUM',
      subtitle: artistName.isNotEmpty ? artistName : null,
      metadata: '$trackCountLabel$durationLabel',
      coverUrl: coverUrl,
      tracks: tracks,
      playbackSource: albumTitle,
      emptyMessage: 'Aucun titre trouvé dans cet album',
      showTrackCovers: false,
    );
  }
}
