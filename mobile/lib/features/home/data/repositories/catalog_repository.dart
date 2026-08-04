import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../../core/network/api_client.dart';
import '../../../player/data/models/track_model.dart';

class CatalogRepository {
  final ApiClient apiClient;
  final YoutubeExplode yt = YoutubeExplode();

  CatalogRepository({required this.apiClient});

  Future<List<TrackModel>> getTrendingTracks({int limit = 20, int offset = 0}) async {
    try {
      final searchResults = await yt.search.search('top hits 2026 musique officielle');
      final videos = searchResults.whereType<Video>().take(limit).toList();
      
      return videos.map((v) => _mapVideoToTrack(v)).toList();
    } catch (e) {
      print('getTrendingTracks error: $e');
      return [];
    }
  }

  Future<List<TrackModel>> searchTracks({String query = '', String genre = '', int limit = 20, int offset = 0}) async {
    try {
      final searchQuery = genre.isNotEmpty ? '$query $genre official music' : '$query official music';
      final searchResults = await yt.search.search(searchQuery);
      final videos = searchResults.whereType<Video>().take(limit).toList();
      
      return videos.map((v) => _mapVideoToTrack(v)).toList();
    } catch (e) {
      print('searchTracks error: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> getGenres() async {
    return [
      {'id': 'rap', 'name': 'Rap'},
      {'id': 'pop', 'name': 'Pop'},
      {'id': 'rnb', 'name': 'R&B'},
      {'id': 'rock', 'name': 'Rock'},
      {'id': 'electro', 'name': 'Electro'},
      {'id': 'afrobeat', 'name': 'Afrobeat'},
      {'id': 'jazz', 'name': 'Jazz'},
      {'id': 'lofi', 'name': 'Lo-Fi'},
    ];
  }

  TrackModel _mapVideoToTrack(Video video) {
    return TrackModel(
      id: video.id.value,
      title: video.title,
      artistName: video.author,
      albumName: 'YouTube Audio',
      coverUrl: video.thumbnails.highResUrl,
      durationSeconds: video.duration?.inSeconds ?? 0,
      audioUrl: '', // L'URL sera résolue juste avant la lecture (pour éviter l'expiration)
      genre: 'YouTube',
      licenseCcUrl: '',
    );
  }
}
