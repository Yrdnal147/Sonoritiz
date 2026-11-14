import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../storage/storage_service.dart';

/// Synchronise la liste des artistes préférés entre le stockage local cloisonné
/// par compte et le backend Django (`/api/auth/preferences/`).
class FavoriteArtistsSyncService {
  final StorageService _storageService;
  final ApiClient _apiClient;

  FavoriteArtistsSyncService({
    StorageService? storageService,
    ApiClient? apiClient,
  })  : _storageService = storageService ?? StorageService(),
        _apiClient = apiClient ?? ApiClient(storageService: storageService ?? StorageService());

  /// Pousse la liste locale de l'utilisateur connecté vers Django.
  /// Ne bloque jamais l'expérience hors-ligne ou en cas de route serveur absente.
  Future<void> pushFavoriteArtists(List<String> artists) async {
    if (!_storageService.isAuthenticated) return;
    final clean = _normalizeList(artists);
    try {
      await _apiClient.patch(
        ApiConstants.userPreferences,
        data: {'favorite_artists': clean},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FavoriteArtistsSync] push skipped: $e');
      }
    }
  }

  /// Synchronise après authentification (login, register, Google sign-in).
  /// - Si le serveur possède déjà des artistes pour ce compte et que le local est vide,
  ///   on restaure la liste serveur localement (cas d'une reconnexion / autre téléphone).
  /// - Si le local contient déjà des artistes pour ce compte et pas le serveur, on pousse.
  Future<List<String>> syncAfterAuth({List<dynamic>? serverArtists}) async {
    final local = _storageService.getFavoriteArtists();
    List<String> remote = _normalizeDynamicList(serverArtists);

    if (remote.isEmpty && serverArtists == null && _storageService.isAuthenticated) {
      remote = await pullFavoriteArtists();
    }

    if (remote.isNotEmpty && local.isEmpty) {
      await _storageService.saveFavoriteArtists(remote);
      return remote;
    }

    if (local.isNotEmpty && remote.isEmpty) {
      await pushFavoriteArtists(local);
      return local;
    }

    if (remote.isNotEmpty && local.isNotEmpty) {
      final merged = _normalizeList([...remote, ...local]);
      if (merged.length != local.length) {
        await _storageService.saveFavoriteArtists(merged);
      }
      return merged;
    }

    return local;
  }

  Future<List<String>> pullFavoriteArtists() async {
    if (!_storageService.isAuthenticated) return const [];
    try {
      final res = await _apiClient.get(ApiConstants.userPreferences);
      if (res.statusCode == 200 && res.data is Map) {
        return _normalizeDynamicList(res.data['favorite_artists']);
      }
    } catch (_) {
      try {
        final meRes = await _apiClient.get(ApiConstants.profile);
        if (meRes.statusCode == 200 && meRes.data is Map) {
          return _normalizeDynamicList(meRes.data['favorite_artists']);
        }
      } catch (_) {}
    }
    return const [];
  }

  static List<String> _normalizeDynamicList(dynamic raw) {
    if (raw is! List) return const [];
    return _normalizeList(raw.map((e) => e.toString()).toList());
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
