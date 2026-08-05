import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../player/data/models/track_model.dart';

class PlaylistModel {
  final int id;
  final String name;
  final String coverUrl;
  final int tracksCount;
  final bool isPinned;
  final List<TrackModel> tracks;

  PlaylistModel({
    required this.id,
    required this.name,
    this.coverUrl = '',
    this.tracksCount = 0,
    this.isPinned = false,
    this.tracks = const [],
  });

  factory PlaylistModel.fromJson(Map<String, dynamic> json) {
    List<TrackModel> trackList = [];
    if (json.containsKey('tracks') && json['tracks'] is List) {
      for (var t in json['tracks']) {
        if (t is Map && t.containsKey('track_details') && t['track_details'] != null) {
          trackList.add(TrackModel.fromJson(t['track_details']));
        }
      }
    }

    return PlaylistModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Ma Playlist',
      coverUrl: json['cover_url'] ?? '',
      tracksCount: json['tracks_count'] ?? trackList.length,
      isPinned: json['is_pinned'] ?? false,
      tracks: trackList,
    );
  }
}

class HistoryModel {
  final int id;
  final String trackId;
  final String playedAt;
  final TrackModel? track;

  HistoryModel({
    required this.id,
    required this.trackId,
    required this.playedAt,
    this.track,
  });

  factory HistoryModel.fromJson(Map<String, dynamic> json) {
    TrackModel? track;
    if (json.containsKey('track_details') && json['track_details'] != null) {
      track = TrackModel.fromJson(json['track_details']);
    }
    return HistoryModel(
      id: json['id'] ?? 0,
      trackId: json['track_id'] ?? '',
      playedAt: json['played_at'] ?? '',
      track: track,
    );
  }
}

class LibraryRepository {
  final ApiClient apiClient;

  LibraryRepository({required this.apiClient});

  // Favorites
  Future<List<TrackModel>> getFavorites() async {
    final response = await apiClient.get(ApiConstants.favorites);
    if (response.statusCode == 200 && response.data is Map && response.data.containsKey('results')) {
      final List results = response.data['results'];
      final List<TrackModel> tracks = [];
      for (var item in results) {
        if (item is Map && item.containsKey('track_details') && item['track_details'] != null) {
          tracks.add(TrackModel.fromJson(item['track_details']));
        }
      }
      return tracks;
    }
    return [];
  }

  Future<void> addFavorite(TrackModel track) async {
    await apiClient.post(ApiConstants.favorites, data: {
      'youtube_id': track.id,
      'title': track.title,
      'artist_name': track.artistName,
      'album_name': track.albumName,
      'cover_url': track.coverUrl,
      'duration_seconds': track.durationSeconds,
    });
  }

  Future<void> removeFavorite(String trackId) async {
    await apiClient.delete('${ApiConstants.favorites}$trackId/');
  }

  // Playlists
  Future<List<PlaylistModel>> getPlaylists() async {
    final response = await apiClient.get(ApiConstants.playlists);
    if (response.statusCode == 200 && response.data is Map && response.data.containsKey('results')) {
      final List results = response.data['results'];
      return results.map((p) => PlaylistModel.fromJson(p)).toList();
    }
    return [];
  }

  Future<PlaylistModel> createPlaylist(String name, {String coverUrl = ''}) async {
    final response = await apiClient.post(ApiConstants.playlists, data: {
      'name': name,
      'cover_url': coverUrl,
    });
    return PlaylistModel.fromJson(response.data);
  }

  Future<void> deletePlaylist(int playlistId) async {
    await apiClient.delete('${ApiConstants.playlists}$playlistId/');
  }

  Future<PlaylistModel> updatePlaylist(int playlistId, {String? name, String? coverUrl, bool? isPinned}) async {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (coverUrl != null) data['cover_url'] = coverUrl;
    if (isPinned != null) data['is_pinned'] = isPinned;
    
    final response = await apiClient.patch('${ApiConstants.playlists}$playlistId/', data: data);
    return PlaylistModel.fromJson(response.data);
  }

  Future<void> addTrackToPlaylist(int playlistId, TrackModel track) async {
    await apiClient.post('${ApiConstants.playlists}$playlistId/tracks/', data: {
      'youtube_id': track.id,
      'title': track.title,
      'artist_name': track.artistName,
      'album_name': track.albumName,
      'cover_url': track.coverUrl,
      'duration_seconds': track.durationSeconds,
    });
  }

  // History
  Future<List<HistoryModel>> getHistory() async {
    final response = await apiClient.get(ApiConstants.history);
    if (response.statusCode == 200 && response.data is Map && response.data.containsKey('results')) {
      final List results = response.data['results'];
      return results.map((h) => HistoryModel.fromJson(h)).toList();
    }
    return [];
  }
}
