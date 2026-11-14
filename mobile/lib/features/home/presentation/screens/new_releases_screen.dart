import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/widgets/sonoritiz_cover_atmosphere.dart';
import '../../../library/data/repositories/library_repository.dart';
import '../../../player/data/models/track_model.dart';
import '../../data/repositories/catalog_repository.dart';

class NewReleasesScreen extends StatefulWidget {
  const NewReleasesScreen({super.key});

  @override
  State<NewReleasesScreen> createState() => _NewReleasesScreenState();
}

class _NewReleasesScreenState extends State<NewReleasesScreen> {
  List<TrackModel> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNewReleases();
  }

  Future<void> _loadNewReleases() async {
    try {
      final storage = StorageService();
      final apiClient = ApiClient(storageService: storage);
      final repo = CatalogRepository(apiClient: apiClient);
      final tracks = await repo.getNewReleasesOfTheWeek(limit: 50);
      if (mounted) {
        setState(() {
          _tracks = tracks;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = _tracks.isNotEmpty ? _tracks.first.coverUrl : '';
    final mosaic = _tracks.length >= 3
        ? PlaylistModel(
            id: -1,
            name: 'Nouveautés de la semaine',
            coverUrl: coverUrl,
            tracks: _tracks.take(4).toList(),
            tracksCount: _tracks.length,
          )
        : null;

    return SonoritizCollectionScaffold(
      title: 'Nouveautés de la semaine',
      badgeLabel: 'SORTIES RÉCENTES',
      subtitle: 'Les dernières pépites ajoutées au catalogue',
      metadata: _tracks.isNotEmpty
          ? '${_tracks.length} ${_tracks.length > 1 ? "titres" : "titre"}'
          : null,
      coverUrl: coverUrl,
      playlistMosaic: mosaic,
      tracks: _tracks,
      playbackSource: 'les nouveautés de la semaine',
      isLoading: _isLoading,
      emptyMessage: 'Aucune nouveauté disponible.',
    );
  }
}
