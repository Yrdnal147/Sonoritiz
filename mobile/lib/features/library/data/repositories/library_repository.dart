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

    String cUrl = json['cover_url'] ?? '';
    if (cUrl.startsWith('http://local.image/')) {
      cUrl = cUrl.replaceFirst('http://local.image/', 'file://');
    }

    return PlaylistModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Ma Playlist',
      coverUrl: cUrl,
      tracksCount: json['tracks_count'] ?? trackList.length,
      isPinned: json['is_pinned'] ?? false,
      tracks: trackList,
    );
  }

  PlaylistModel copyWith({
    int? id,
    String? name,
    String? coverUrl,
    int? tracksCount,
    bool? isPinned,
    List<TrackModel>? tracks,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      coverUrl: coverUrl ?? this.coverUrl,
      tracksCount: tracksCount ?? this.tracksCount,
      isPinned: isPinned ?? this.isPinned,
      tracks: tracks ?? this.tracks,
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
      trackId: (json['track_id'] ?? json['youtube_id'] ?? '').toString(),
      playedAt: json['played_at'] ?? '',
      track: track,
    );
  }
}

class FavoriteAlbumModel {
  final String id;
  final String title;
  final String artistName;
  final String coverUrl;
  final String year;
  final int tracksCount;
  final List<TrackModel> tracks;
  final String addedAt;

  const FavoriteAlbumModel({
    required this.id,
    required this.title,
    required this.artistName,
    this.coverUrl = '',
    this.year = '',
    this.tracksCount = 0,
    this.tracks = const [],
    this.addedAt = '',
  });

  String get identityKey => computeIdentityKey(
        id: id,
        title: title,
        artistName: artistName,
      );

  static String computeIdentityKey({
    String? id,
    required String title,
    required String artistName,
  }) {
    final cleanId = (id ?? '').trim();
    if (cleanId.isNotEmpty && cleanId != '0') {
      return 'id:$cleanId';
    }
    return 'meta:${title.trim().toLowerCase()}__${artistName.trim().toLowerCase()}';
  }

  factory FavoriteAlbumModel.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['tracks'] as List? ?? const [];
    final parsedTracks = rawTracks
        .whereType<Map>()
        .map((e) => TrackModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return FavoriteAlbumModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Album').toString(),
      artistName: (json['artist_name'] ?? json['artistName'] ?? 'Artiste').toString(),
      coverUrl: (json['cover_url'] ?? json['coverUrl'] ?? '').toString(),
      year: (json['year'] ?? '').toString(),
      tracksCount: (json['tracks_count'] is int)
          ? json['tracks_count'] as int
          : parsedTracks.length,
      tracks: parsedTracks,
      addedAt: (json['added_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist_name': artistName,
      'cover_url': coverUrl,
      'year': year,
      'tracks_count': tracksCount > 0 ? tracksCount : tracks.length,
      'tracks': tracks.map((t) => t.toJson()).toList(),
      'added_at': addedAt,
    };
  }

  Map<String, dynamic> toRouteExtra() {
    final parsedId = int.tryParse(id);
    return {
      if (parsedId != null && parsedId > 0) 'id': parsedId,
      'title': title,
      'artistName': artistName,
      'cover': coverUrl,
      'cover_xl': coverUrl,
      if (year.isNotEmpty) 'release_date': '$year-01-01',
    };
  }
}

class LibraryRepository {
  final ApiClient apiClient;

  LibraryRepository({required this.apiClient});

  // Favorites (paginé pour préserver l'intégralité des titres lors des reconnexions)
  Future<List<TrackModel>> getFavorites() async {
    final List<TrackModel> allTracks = [];
    final Set<String> seenIds = {};
    int offset = 0;
    const int limit = 50;

    for (int page = 0; page < 20; page++) {
      final response = await apiClient.get(
        '${ApiConstants.favorites}?limit=$limit&offset=$offset',
      );
      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('results')) {
          final List results = response.data['results'] as List? ?? [];
          for (final item in results) {
            if (item is Map && item['track_details'] != null) {
              final track = TrackModel.fromJson(
                Map<String, dynamic>.from(item['track_details'] as Map),
              );
              if (seenIds.add(track.id)) {
                allTracks.add(track);
              }
            }
          }
          final nextUrl = response.data['next'];
          if (nextUrl == null || results.length < limit) {
            return allTracks;
          }
          offset += limit;
        } else if (response.data is List) {
          for (final item in response.data as List) {
            if (item is Map && item['track_details'] != null) {
              final track = TrackModel.fromJson(
                Map<String, dynamic>.from(item['track_details'] as Map),
              );
              if (seenIds.add(track.id)) {
                allTracks.add(track);
              }
            }
          }
          return allTracks;
        } else {
          break;
        }
      } else {
        throw Exception('Failed to load favorites: status code ${response.statusCode}');
      }
    }
    return allTracks;
  }

  Future<bool> isFavorite(String trackId) async {
    try {
      final favs = await getFavorites();
      return favs.any((t) => t.id == trackId);
    } catch (e) {
      return false;
    }
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
  String _sanitizeServerCoverUrl(String coverUrl) {
    final trimmed = coverUrl.trim();
    if (trimmed.isEmpty) return '';
    final serverValue = trimmed.startsWith('file://')
        ? trimmed.replaceFirst('file://', 'http://local.image/')
        : trimmed;
    // Le modèle Django Playlist.cover_url est limité à 500 caractères.
    if (serverValue.length > 500) {
      return '';
    }
    return serverValue;
  }

  Future<List<PlaylistModel>> getPlaylists() async {
    final List<PlaylistModel> allPlaylists = [];
    int offset = 0;
    const int limit = 50;

    for (int page = 0; page < 10; page++) {
      final response = await apiClient.get(
        '${ApiConstants.playlists}?limit=$limit&offset=$offset',
      );
      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('results')) {
          final List results = response.data['results'] as List? ?? [];
          allPlaylists.addAll(
            results.map((p) => PlaylistModel.fromJson(Map<String, dynamic>.from(p as Map))),
          );
          final nextUrl = response.data['next'];
          if (nextUrl == null || results.length < limit) {
            return allPlaylists;
          }
          offset += limit;
        } else if (response.data is List) {
          final List results = response.data as List;
          return results
              .map((p) => PlaylistModel.fromJson(Map<String, dynamic>.from(p as Map)))
              .toList();
        } else {
          break;
        }
      } else {
        throw Exception('Failed to load playlists: status code ${response.statusCode}');
      }
    }
    return allPlaylists;
  }

  Future<PlaylistModel> createPlaylist(String name, {String coverUrl = ''}) async {
    final safeCover = _sanitizeServerCoverUrl(coverUrl);
    final response = await apiClient.post(ApiConstants.playlists, data: {
      'name': name,
      'cover_url': safeCover,
    });
    if (response.data is Map) {
      return PlaylistModel.fromJson(Map<String, dynamic>.from(response.data as Map));
    }
    throw Exception('Failed to parse created playlist response');
  }

  Future<void> deletePlaylist(int playlistId) async {
    await apiClient.delete('${ApiConstants.playlists}$playlistId/');
  }

  Future<PlaylistModel> updatePlaylist(int playlistId, {String? name, String? coverUrl, bool? isPinned}) async {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (coverUrl != null) data['cover_url'] = _sanitizeServerCoverUrl(coverUrl);
    if (isPinned != null) data['is_pinned'] = isPinned;
    
    final response = await apiClient.patch('${ApiConstants.playlists}$playlistId/', data: data);
    if (response.data is Map) {
      return PlaylistModel.fromJson(Map<String, dynamic>.from(response.data as Map));
    }
    throw Exception('Failed to parse updated playlist response');
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

  Future<void> removeTrackFromPlaylist(int playlistId, String trackId) async {
    await apiClient.delete('${ApiConstants.playlists}$playlistId/tracks/$trackId/');
  }

  // History
  Future<List<HistoryModel>> getHistory() async {
    final List<HistoryModel> allHistory = [];
    int offset = 0;
    const int limit = 50;

    for (int page = 0; page < 5; page++) {
      final response = await apiClient.get(
        '${ApiConstants.history}?limit=$limit&offset=$offset',
      );
      if (response.statusCode == 200 &&
          response.data is Map &&
          response.data.containsKey('results')) {
        final List results = response.data['results'];
        allHistory.addAll(results.map((h) => HistoryModel.fromJson(h)));
        final nextUrl = response.data['next'];
        if (nextUrl == null || results.length < limit) {
          break;
        }
        offset += limit;
      } else {
        break;
      }
    }
    return allHistory;
  }

  Future<void> addToHistory(TrackModel track) async {
    try {
      await apiClient.post(ApiConstants.history, data: {
        'youtube_id': track.id,
        'jamendo_track_id': track.id,
        'track_data': track.toJson(),
      });
    } catch (e) {
      print("Erreur lors de l'ajout à l'historique: $e");
    }
  }
}
