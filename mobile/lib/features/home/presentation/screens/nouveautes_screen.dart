import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/widgets/sonoritiz_cover_atmosphere.dart';
import '../../../library/data/repositories/library_repository.dart';
import '../../../player/data/models/track_model.dart';
import '../../data/repositories/catalog_repository.dart';

class NouveautesScreen extends StatefulWidget {
  const NouveautesScreen({super.key});

  @override
  State<NouveautesScreen> createState() => _NouveautesScreenState();
}

class _NouveautesScreenState extends State<NouveautesScreen> {
  late CatalogRepository _repository;
  bool _isLoading = true;
  List<TrackModel> _tracks = [];

  @override
  void initState() {
    super.initState();
    final storage = StorageService();
    _repository =
        CatalogRepository(apiClient: ApiClient(storageService: storage));
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final tracks = await _repository.getTrendingTracks(limit: 50);
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
            name: 'Top 50 • Classement Mondial',
            coverUrl: coverUrl,
            tracks: _tracks.take(4).toList(),
            tracksCount: _tracks.length,
          )
        : null;

    return SonoritizCollectionScaffold(
      title: 'Top 50 • Classement Mondial',
      badgeLabel: 'CLASSEMENT MONDIAL',
      subtitle: 'Les titres les plus écoutés en ce moment',
      metadata: _tracks.isNotEmpty
          ? '${_tracks.length} ${_tracks.length > 1 ? "titres" : "titre"}'
          : null,
      coverUrl: coverUrl,
      playlistMosaic: mosaic,
      tracks: _tracks,
      playbackSource: 'Top 50 Mondial',
      isLoading: _isLoading,
      emptyMessage: 'Aucun titre disponible pour le moment.',
    );
  }
}
