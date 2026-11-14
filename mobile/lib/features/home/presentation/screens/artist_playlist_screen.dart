import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/widgets/sonoritiz_cover_atmosphere.dart';
import '../../../library/data/repositories/library_repository.dart';
import '../../../player/data/models/track_model.dart';
import '../../data/repositories/catalog_repository.dart';

class ArtistPlaylistScreen extends StatefulWidget {
  final String artistName;

  const ArtistPlaylistScreen({super.key, required this.artistName});

  @override
  State<ArtistPlaylistScreen> createState() => _ArtistPlaylistScreenState();
}

class _ArtistPlaylistScreenState extends State<ArtistPlaylistScreen> {
  late CatalogRepository _repository;
  bool _isLoading = true;
  List<TrackModel> _tracks = [];

  @override
  void initState() {
    super.initState();
    final storage = StorageService();
    _repository = CatalogRepository(apiClient: ApiClient(storageService: storage));
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final tracks = await _repository.getArtistTopTracks(widget.artistName, limit: 20);
      if (mounted) {
        setState(() {
          _tracks = tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTotalDuration() {
    if (_tracks.isEmpty) return '';
    int totalSeconds = 0;
    for (final t in _tracks) {
      totalSeconds += t.durationSeconds > 0 ? t.durationSeconds : 195;
    }
    final hours = totalSeconds ~/ 3600;
    final mins = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '$hours h ${mins.toString().padLeft(2, '0')} min';
    return '$mins min';
  }

  @override
  Widget build(BuildContext context) {
    final sourceLabel = "la sélection ${widget.artistName}";
    String heroCover = '';
    for (final t in _tracks) {
      if (t.coverUrl.isNotEmpty) {
        heroCover = t.coverUrl;
        break;
      }
    }
    final duration = _formatTotalDuration();

    return SonoritizCollectionScaffold(
      title: widget.artistName,
      badgeLabel: 'SÉLECTION ARTISTE',
      subtitle: 'Titres populaires & essentiels',
      onSubtitleTap: () => context.push(
        '/artist',
        extra: {'name': widget.artistName},
      ),
      metadata: _tracks.isNotEmpty
          ? "${_tracks.length} morceaux sélectionnés${duration.isNotEmpty ? ' • $duration' : ''}"
          : null,
      coverUrl: heroCover,
      playlistMosaic: _tracks.length >= 3
          ? PlaylistModel(
              id: -1,
              name: widget.artistName,
              tracks: _tracks,
            )
          : null,
      tracks: _tracks,
      playbackSource: sourceLabel,
      isLoading: _isLoading,
      showTrackCovers: true,
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.person_search_rounded, color: Colors.white70),
          tooltip: "Voir la page artiste",
          onPressed: () => context.push(
            '/artist',
            extra: {'name': widget.artistName},
          ),
        ),
      ],
    );
  }
}
