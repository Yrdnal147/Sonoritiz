import 'package:flutter/foundation.dart';
import '../../features/library/data/repositories/library_repository.dart'
    show FavoriteAlbumModel;
import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../storage/storage_service.dart';

/// Synchronise les préférences du compte (artistes favoris, Sonoritiz Superlikes,
/// albums favoris) entre le stockage local cloisonné et Django (`/api/auth/preferences/`).
class FavoriteArtistsSyncService {
  final StorageService _storageService;
  final ApiClient _apiClient;

  FavoriteArtistsSyncService({
    StorageService? storageService,
    ApiClient? apiClient,
  })  : _storageService = storageService ?? StorageService(),
        _apiClient =
            apiClient ?? ApiClient(storageService: storageService ?? StorageService());

  Future<void> _pushPreference(String field, dynamic value) async {
    if (!_storageService.isAuthenticated) return;
    try {
      await _apiClient.patch(
        ApiConstants.userPreferences,
        data: {field: value},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PreferencesSync] push $field skipped: $e');
      }
    }
  }

  /// Pousse la liste d'artistes préférés vers Django.
  Future<void> pushFavoriteArtists(List<String> artists) async {
    await _pushPreference('favorite_artists', _normalizeList(artists));
  }

  /// Pousse les Sonoritiz Superlikes (max 20) vers Django.
  Future<void> pushSuperlikes(List<Map<String, dynamic>> tracks) async {
    await _pushPreference('superliked_tracks', _normalizeTrackMaps(tracks));
  }

  /// Pousse les albums favoris vers Django.
  Future<void> pushFavoriteAlbums(List<Map<String, dynamic>> albums) async {
    await _pushPreference('favorite_albums', _normalizeAlbumMaps(albums));
  }

  /// Synchronise artistes préférés, superlikes et albums favoris après authentification.
  Future<List<String>> syncAfterAuth({
    List<dynamic>? serverArtists,
    List<dynamic>? serverSuperlikes,
    List<dynamic>? serverFavoriteAlbums,
  }) async {
    Map<String, List<dynamic>>? pulled;
    if ((serverArtists == null ||
            serverSuperlikes == null ||
            serverFavoriteAlbums == null) &&
        _storageService.isAuthenticated) {
      pulled = await _pullAllPreferences();
    }

    final remoteArtists = _normalizeDynamicList(
      serverArtists ?? pulled?['favorite_artists'],
    );
    final remoteSuperlikes = _normalizeDynamicMapList(
      serverSuperlikes ?? pulled?['superliked_tracks'],
      _normalizeTrackMaps,
    );
    final remoteAlbums = _normalizeDynamicMapList(
      serverFavoriteAlbums ?? pulled?['favorite_albums'],
      _normalizeAlbumMaps,
    );

    final reconciledArtists = await _reconcileList<String>(
      local: _normalizeList(_storageService.getFavoriteArtists()),
      remote: remoteArtists,
      keyOf: (artist) => artist.trim().toLowerCase(),
      maxItems: 50,
      saveLocal: (items) =>
          _storageService.saveFavoriteArtists(items, syncToServer: false),
      pushRemote: pushFavoriteArtists,
    );

    await _reconcileList<Map<String, dynamic>>(
      local: _normalizeTrackMaps(_storageService.getSuperlikesRaw()),
      remote: remoteSuperlikes,
      keyOf: _trackIdentityKey,
      maxItems: 20,
      saveLocal: (items) =>
          _storageService.saveSuperlikesRaw(items, syncToServer: false),
      pushRemote: pushSuperlikes,
    );

    await _reconcileList<Map<String, dynamic>>(
      local: _normalizeAlbumMaps(_storageService.getFavoriteAlbumsRaw()),
      remote: remoteAlbums,
      keyOf: _albumIdentityKey,
      maxItems: 150,
      saveLocal: (items) =>
          _storageService.saveFavoriteAlbumsRaw(items, syncToServer: false),
      pushRemote: pushFavoriteAlbums,
    );

    return reconciledArtists;
  }

  Future<List<T>> _reconcileList<T>({
    required List<T> local,
    required List<T> remote,
    required String Function(T) keyOf,
    required int maxItems,
    required Future<void> Function(List<T>) saveLocal,
    required Future<void> Function(List<T>) pushRemote,
  }) async {
    if (remote.isNotEmpty && local.isEmpty) {
      await saveLocal(remote);
      return remote;
    }

    if (local.isNotEmpty && remote.isEmpty) {
      await pushRemote(local);
      return local;
    }

    if (remote.isNotEmpty && local.isNotEmpty) {
      final seen = <String>{};
      final merged = <T>[];
      for (final item in [...remote, ...local]) {
        final key = keyOf(item);
        if (key.isEmpty || !seen.add(key)) continue;
        merged.add(item);
        if (merged.length >= maxItems) break;
      }
      if (!_sameKeySequence(merged, local, keyOf)) {
        await saveLocal(merged);
      }
      if (!_sameKeySequence(merged, remote, keyOf)) {
        await pushRemote(merged);
      }
      return merged;
    }

    return local;
  }

  static bool _sameKeySequence<T>(
    List<T> a,
    List<T> b,
    String Function(T) keyOf,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (keyOf(a[i]) != keyOf(b[i])) return false;
    }
    return true;
  }

  Future<List<String>> pullFavoriteArtists() async {
    final prefs = await _pullAllPreferences();
    return _normalizeDynamicList(prefs['favorite_artists']);
  }

  Future<Map<String, List<dynamic>>> _pullAllPreferences() async {
    if (!_storageService.isAuthenticated) return const {};
    for (final endpoint in const [ApiConstants.userPreferences, ApiConstants.profile]) {
      try {
        final res = await _apiClient.get(endpoint);
        if (res.statusCode == 200 && res.data is Map) {
          final data = res.data as Map;
          return {
            'favorite_artists':
                data['favorite_artists'] is List ? data['favorite_artists'] as List : const [],
            'superliked_tracks':
                data['superliked_tracks'] is List ? data['superliked_tracks'] as List : const [],
            'favorite_albums':
                data['favorite_albums'] is List ? data['favorite_albums'] as List : const [],
          };
        }
      } catch (_) {}
    }
    return const {};
  }

  static List<String> _normalizeDynamicList(dynamic raw) {
    if (raw is! List) return const [];
    return _normalizeList(raw.map((e) => e.toString()).toList());
  }

  static List<Map<String, dynamic>> _normalizeDynamicMapList(
    dynamic raw,
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>>) normalizer,
  ) {
    if (raw is! List) return const [];
    final maps = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return normalizer(maps);
  }

  static String _trackIdentityKey(Map<String, dynamic> track) {
    return (track['id'] ?? track['youtube_id'] ?? '').toString().trim();
  }

  static String _albumIdentityKey(Map<String, dynamic> album) {
    return FavoriteAlbumModel.computeIdentityKey(
      id: album['id']?.toString(),
      title: (album['title'] ?? '').toString(),
      artistName: (album['artist_name'] ?? album['artistName'] ?? '').toString(),
    );
  }

  static List<Map<String, dynamic>> _normalizeTrackMaps(
    List<Map<String, dynamic>> items,
  ) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final raw in items) {
      final key = _trackIdentityKey(raw);
      if (key.isEmpty || !seen.add(key)) continue;
      final copy = Map<String, dynamic>.from(raw);
      copy['id'] = key;
      result.add(copy);
      if (result.length >= 20) break;
    }
    return result;
  }

  static List<Map<String, dynamic>> _normalizeAlbumMaps(
    List<Map<String, dynamic>> items,
  ) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final raw in items) {
      final id = (raw['id'] ?? '').toString().trim();
      final title = (raw['title'] ?? '').toString().trim();
      if (id.isEmpty && title.isEmpty) continue;
      final key = _albumIdentityKey(raw);
      if (!seen.add(key)) continue;
      result.add(Map<String, dynamic>.from(raw));
      if (result.length >= 150) break;
    }
    return result;
  }

  static List<String> _normalizeList(List<String> items) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in items) {
      final clean = raw.trim();
      if (clean.isEmpty) continue;
      if (seen.add(clean.toLowerCase())) {
        result.add(clean);
      }
    }
    return result;
  }
}
