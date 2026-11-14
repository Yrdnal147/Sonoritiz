import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sonoritiz_cover_atmosphere.dart';
import '../../../library/data/repositories/library_repository.dart';
import '../../../player/data/models/track_model.dart';
import '../../data/repositories/catalog_repository.dart';

class CategoryListScreen extends StatefulWidget {
  final Map<String, dynamic> category;

  const CategoryListScreen({super.key, required this.category});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  late CatalogRepository _catalogRepository;
  List<TrackModel> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _catalogRepository = CatalogRepository(
      apiClient: ApiClient(storageService: StorageService()),
    );
    _loadData();
  }

  Future<void> _loadData() async {
    final genreId = widget.category['id'];
    final query =
        (widget.category['query'] ?? widget.category['title'] ?? '').toString();
    List<TrackModel> results = [];

    if (genreId != null && genreId != 0) {
      results = await _catalogRepository.getTracksByGenreId(
        genreId,
        genreName: query,
        limit: 60,
      );
    }

    if (results.isEmpty && query.isNotEmpty) {
      results = await _catalogRepository.searchTracks(query: query, limit: 60);
    }

    if (mounted) {
      setState(() {
        _tracks = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.category['title'] as String? ?? 'Genre';
    final color = (widget.category['color'] is Color)
        ? widget.category['color'] as Color
        : AppColors.primary;
    final coverUrl =
        _tracks.isNotEmpty ? _tracks.first.coverUrl : '';
    final mosaicPlaylist = _tracks.length >= 3
        ? PlaylistModel(
            id: -1,
            name: title,
            coverUrl: coverUrl,
            tracks: _tracks.take(4).toList(),
            tracksCount: _tracks.length,
          )
        : null;

    return SonoritizCollectionScaffold(
      title: title,
      badgeLabel: 'GENRE & SÉLECTION',
      metadata: _tracks.isNotEmpty
          ? '${_tracks.length} ${_tracks.length > 1 ? "titres" : "titre"}'
          : null,
      coverUrl: coverUrl,
      playlistMosaic: mosaicPlaylist,
      tracks: _tracks,
      playbackSource: title,
      isLoading: _isLoading,
      emptyMessage: 'Aucun son trouvé pour ce genre.',
      fallbackAccentColor: color,
    );
  }
}
