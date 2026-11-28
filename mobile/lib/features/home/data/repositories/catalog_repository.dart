import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Color;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:dio/dio.dart' as dio_pkg;
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/json_cache.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../player/data/models/track_model.dart';
import '../../domain/recommendation_engine.dart';

class _CachedWebResponse {
  final dynamic data;
  final DateTime expiresAt;
  const _CachedWebResponse(this.data, this.expiresAt);
}

class CatalogRepository {
  static final Map<String, _CachedWebResponse> _webProxyCache = {};

  final ApiClient apiClient;
  final YoutubeExplode yt = YoutubeExplode();
  final dio_pkg.Dio _externalDio = dio_pkg.Dio(
    dio_pkg.BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 8),
    ),
  );

  CatalogRepository({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient(storageService: StorageService()) {
    if (kIsWeb) {
      _installWebCorsProxyInterceptor();
    }
  }

  void _installWebCorsProxyInterceptor() {
    _externalDio.interceptors.add(
      dio_pkg.InterceptorsWrapper(
        onRequest: (options, handler) {
          final rawUrl = options.uri.toString();
          if (rawUrl.startsWith('https://api.deezer.com/') ||
              rawUrl.startsWith('https://itunes.apple.com/')) {
            final cached = _webProxyCache[rawUrl];
            if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
              return handler.resolve(
                dio_pkg.Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: cached.data,
                ),
              );
            }
            options.extra['__original_external_url__'] = rawUrl;
            final proxyUrl =
                '${ApiConstants.baseUrl}/api/tracks/deezer-proxy/?url=${Uri.encodeComponent(rawUrl)}';
            options.path = proxyUrl;
            options.queryParameters = const {};
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          final originalUrl =
              response.requestOptions.extra['__original_external_url__'] as String?;
          if (originalUrl != null && response.statusCode == 200) {
            dynamic payload = response.data;
            if (payload is String && payload.isNotEmpty) {
              try {
                payload = jsonDecode(payload);
                response.data = payload;
              } catch (_) {}
            }
            final ttl = originalUrl.contains('/track/')
                ? const Duration(minutes: 4)
                : const Duration(minutes: 10);
            if (_webProxyCache.length > 200) {
              _webProxyCache.remove(_webProxyCache.keys.first);
            }
            _webProxyCache[originalUrl] =
                _CachedWebResponse(payload, DateTime.now().add(ttl));
          }
          handler.next(response);
        },
        onError: (err, handler) async {
          final originalUrl =
              err.requestOptions.extra['__original_external_url__'] as String?;
          final alreadyRetried =
              err.requestOptions.extra['__retried_fallback_proxy__'] == true;
          if (originalUrl != null && !alreadyRetried) {
            try {
              final fallbackDio = dio_pkg.Dio(
                dio_pkg.BaseOptions(
                  connectTimeout: const Duration(seconds: 7),
                  receiveTimeout: const Duration(seconds: 9),
                ),
              );
              final fallbackRes = await fallbackDio.get(
                'https://api.codetabs.com/v1/proxy?quest=${Uri.encodeComponent(originalUrl)}',
              );
              if (fallbackRes.statusCode == 200 && fallbackRes.data != null) {
                dynamic payload = fallbackRes.data;
                if (payload is String && payload.isNotEmpty) {
                  try {
                    payload = jsonDecode(payload);
                  } catch (_) {}
                }
                final ttl = originalUrl.contains('/track/')
                    ? const Duration(minutes: 4)
                    : const Duration(minutes: 10);
                _webProxyCache[originalUrl] =
                    _CachedWebResponse(payload, DateTime.now().add(ttl));
                return handler.resolve(
                  dio_pkg.Response(
                    requestOptions: err.requestOptions,
                    statusCode: 200,
                    data: payload,
                  ),
                );
              }
            } catch (_) {}
          }
          handler.next(err);
        },
      ),
    );
  }

  /// Extrait le nom complet de l'artiste principal + les artistes en featuring
  /// depuis le champ `contributors` de Deezer ou depuis le titre `(feat. ...)`.
  String _extractDeezerArtistName(Map<String, dynamic> t, {String? fallbackArtist}) {
    final String mainArtist = (t['artist']?['name'] ?? fallbackArtist ?? 'Unknown Artist').toString().trim();
    final List<String> artists = [mainArtist];

    // 1. Vérifier la liste `contributors` fournie par Deezer
    if (t['contributors'] is List) {
      for (final c in (t['contributors'] as List)) {
        if (c is Map && c['name'] != null) {
          final name = c['name'].toString().trim();
          if (name.isNotEmpty && !artists.any((a) => a.toLowerCase() == name.toLowerCase())) {
            artists.add(name);
          }
        }
      }
    }

    // 2. Si `contributors` n'était pas présent, chercher (feat. X) / [ft. X] dans title ou title_version
    if (artists.length == 1) {
      final String title = '${t['title'] ?? ''} ${t['title_version'] ?? ''}'.trim();
      final RegExp parenFeat = RegExp(
        r'[\(\[]\s*(?:feat\.?|ft\.?|featuring|with|avec)\s+([^\)\]]+)[\)\]]',
        caseSensitive: false,
      );
      final RegExp inlineFeat = RegExp(
        r'\s+(?:feat\.?|ft\.?|featuring)\s+([^\-\(\[\|]+)',
        caseSensitive: false,
      );

      final match = parenFeat.firstMatch(title) ?? inlineFeat.firstMatch(title);
      if (match != null && match.group(1) != null) {
        final featRaw = match.group(1)!.trim();
        final featNames = featRaw
            .split(RegExp(r'\s*(?:,|&|\band\b|\bet\b|\bx\b)\s*', caseSensitive: false))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty);
        for (final name in featNames) {
          if (!artists.any((a) => a.toLowerCase() == name.toLowerCase())) {
            artists.add(name);
          }
        }
      }
    }

    if (artists.length <= 1) return mainArtist;
    return '${artists.first} feat. ${artists.sublist(1).join(', ')}';
  }

  /// Nettoie le titre en retirant la mention (feat. ...) déjà affichée dans l'artiste
  String _cleanDeezerTitle(Map<String, dynamic> t) {
    final String rawTitle = (t['title_short'] ?? t['title'] ?? '').toString().trim();
    if (rawTitle.isEmpty) return '';
    return rawTitle
        .replaceAll(
          RegExp(r'\s*[\(\[]\s*(?:feat\.?|ft\.?|featuring)\s+[^\)\]]+[\)\]]', caseSensitive: false),
          '',
        )
        .trim();
  }

  // Méthode utilitaire pour mapper un son Deezer
  TrackModel _mapDeezerTrack(Map<String, dynamic> t) {
    return TrackModel(
      id: 'deezer_${t['id']}',
      title: _cleanDeezerTitle(t),
      artistName: _extractDeezerArtistName(t),
      albumName: t['album']?['title'] ?? '',
      coverUrl: t['album']?['cover_xl'] ?? t['album']?['cover_medium'] ?? t['album']?['cover'] ?? '',
      durationSeconds: t['duration'] ?? 0,
      audioUrl: (t['preview'] ?? '').toString(),
      genre: '',
      licenseCcUrl: '',
    );
  }

  // 0. Nouveautés de la semaine / Sons à venir (via Deezer Editorial)
  Future<List<TrackModel>> getNewReleasesOfTheWeek({int limit = 20}) async {
    final dioClient = _externalDio;
    for (final q in ['Nouveautés vendredi', 'New Music Friday', 'Nouveautés du moment']) {
      try {
        final playlistResponse = await dioClient.get(
          'https://api.deezer.com/search/playlist?q=${Uri.encodeComponent(q)}&limit=1',
        );
        if (playlistResponse.statusCode == 200 &&
            playlistResponse.data is Map &&
            playlistResponse.data['data'] is List &&
            (playlistResponse.data['data'] as List).isNotEmpty) {
          final playlistId = playlistResponse.data['data'][0]['id'];
          final tracksResponse = await dioClient.get(
            'https://api.deezer.com/playlist/$playlistId/tracks?limit=$limit',
          );
          if (tracksResponse.statusCode == 200 &&
              tracksResponse.data is Map &&
              tracksResponse.data['data'] is List) {
            final data = tracksResponse.data['data'] as List;
            if (data.isNotEmpty) {
              return data
                  .whereType<Map<String, dynamic>>()
                  .map(_mapDeezerTrack)
                  .toList();
            }
          }
        }
      } catch (e) {
        print('getNewReleasesOfTheWeek ($q) error: $e');
      }
    }

    // Secours : titres des dernières sorties éditoriales (singles/EPs)
    try {
      final relRes = await dioClient.get('https://api.deezer.com/editorial/0/releases?limit=8');
      if (relRes.statusCode == 200 &&
          relRes.data is Map &&
          relRes.data['data'] is List) {
        final albums = (relRes.data['data'] as List).whereType<Map>().take(5).toList();
        final futures = albums.map((a) async {
          try {
            final albumId = a['id'];
            final albumTitle = (a['title'] ?? '').toString();
            final albumCover = (a['cover_xl'] ?? a['cover_big'] ?? a['cover_medium'] ?? a['cover'] ?? '').toString();
            final trRes = await dioClient.get('https://api.deezer.com/album/$albumId/tracks?limit=4');
            if (trRes.statusCode == 200 && trRes.data is Map && trRes.data['data'] is List) {
              return (trRes.data['data'] as List).whereType<Map<String, dynamic>>().map((t) {
                t['album'] ??= {'title': albumTitle, 'cover_xl': albumCover};
                return _mapDeezerTrack(t);
              }).toList();
            }
          } catch (_) {}
          return <TrackModel>[];
        });
        final nested = await Future.wait(futures);
        final flat = nested.expand((e) => e).toList();
        if (flat.isNotEmpty) return flat.take(limit).toList();
      }
    } catch (_) {}

    return [];
  }

  // 1. Tendances globales (Vrai Top 50 Mondial officiel Deezer Charts)
  Future<List<TrackModel>> getTrendingTracks({int limit = 50, int offset = 0}) async {
    try {
      // 1. Priorité absolue : Playlist officielle Deezer "Top Worldwide" (ID: 3155776842)
      // C'est le vrai classement mondial certifié avec les plus grands tubes planétaires du moment.
      final worldwideTracks = await getPlaylistTracksDeezer('3155776842', limit: limit);
      if (worldwideTracks.isNotEmpty) {
        return worldwideTracks;
      }
    } catch (_) {}

    try {
      // 2. Fallback Deezer Chart 0 en filtrant impérativement les comptines / berceuses
      final dioClient = _externalDio;
      final response = await dioClient.get('https://api.deezer.com/chart/0/tracks?limit=${limit + 20}');
      if (response.statusCode == 200 && response.data['data'] != null) {
        final data = response.data['data'] as List;
        final cleanList = data.where((t) {
          final title = (t['title'] ?? '').toString().toLowerCase();
          final artist = (t['artist']?['name'] ?? '').toString().toLowerCase();
          // Exclure les comptines / berceuses enfants qui polluent parfois le chart brut
          if (artist.contains('titounis') ||
              artist.contains('comptines') ||
              title.contains('petite étoile') ||
              title.contains('berceuse')) {
            return false;
          }
          return true;
        }).take(limit).toList();

        return cleanList.map((t) => _mapDeezerTrack(t as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      print('getTrendingTracks error: $e');
    }
    return [];
  }

  // 1.1 Playlists éditoriales officielles Deezer (Top charts playlists)
  Future<List<Map<String, dynamic>>> getEditorialPlaylists({int limit = 12}) async {
    try {
      final dioClient = _externalDio;
      final response = await dioClient.get('https://api.deezer.com/chart/0/playlists?limit=$limit');
      if (response.statusCode == 200 && response.data['data'] != null) {
        final data = response.data['data'] as List;
        return data.map((p) {
          final map = p as Map<String, dynamic>;
          final rawTitle = (map['title'] ?? 'Sélection Sonoritiz').toString();
          final cleanTitle = rawTitle
              .replaceAll(RegExp(r'\bdeezer\b', caseSensitive: false), 'Sonoritiz')
              .trim();
          final rawCreator = (map['creator']?['name'] ?? '').toString().trim();
          final cleanCreator = (rawCreator.isEmpty ||
                  rawCreator.toLowerCase().contains('deezer'))
              ? 'Sonoritiz'
              : rawCreator;
          return {
            'id': map['id'],
            'title': cleanTitle.isNotEmpty ? cleanTitle : 'Sélection Sonoritiz',
            'picture': (map['picture_xl'] ?? map['picture_big'] ?? map['picture_medium'] ?? map['picture'] ?? '').toString(),
            'nb_tracks': int.tryParse(map['nb_tracks']?.toString() ?? '0') ?? 0,
            'creator': cleanCreator,
          };
        }).toList();
      }
    } catch (e) {
      print('getEditorialPlaylists error: $e');
    }
    return [];
  }

  // 1.2 Récupère les sons d'une playlist Deezer par son ID
  Future<List<TrackModel>> getPlaylistTracksDeezer(dynamic playlistId, {int limit = 50}) async {
    try {
      final dioClient = _externalDio;
      final response = await dioClient.get('https://api.deezer.com/playlist/$playlistId/tracks?limit=$limit');
      if (response.statusCode == 200 && response.data['data'] != null) {
        final data = response.data['data'] as List;
        return data.map((t) => _mapDeezerTrack(t as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      print('getPlaylistTracksDeezer error: $e');
    }
    return [];
  }

  /// Interligne et déduplique des morceaux provenant de plusieurs playlists Deezer.
  Future<List<TrackModel>> _interleavePlaylists(
    List<String> playlistIds, {
    int perPlaylist = 12,
    int limit = 30,
    Set<String> excludeIds = const {},
    Set<String> excludeTitleKeys = const {},
  }) async {
    if (playlistIds.isEmpty) return [];
    final lists = await Future.wait(
      playlistIds.map(
        (id) => getPlaylistTracksDeezer(id, limit: perPlaylist)
            .catchError((_) => <TrackModel>[]),
      ),
    );

    final List<TrackModel> result = [];
    final Set<String> seenIds = {...excludeIds};
    final Set<String> seenKeys = {...excludeTitleKeys};
    int maxLen = 0;
    for (final list in lists) {
      if (list.length > maxLen) maxLen = list.length;
    }

    for (int i = 0; i < maxLen && result.length < limit; i++) {
      for (final list in lists) {
        if (i >= list.length) continue;
        final t = list[i];
        if (t.title.isEmpty) continue;
        final key = '${t.title.toLowerCase()}__${t.artistName.toLowerCase()}';
        if (seenIds.add(t.id) && seenKeys.add(key)) {
          result.add(t);
          if (result.length >= limit) break;
        }
      }
    }
    return result;
  }

  // 1.3 Sons par Ambiance du Quotidien (Soirée, Nocturne, Sport, Détente, Focus, Trajet)
  Future<List<TrackModel>> getTracksByMood(String moodTag, {int limit = 25}) async {
    List<String> playlistIds = const [];
    String fallbackQuery = 'chill hits';
    switch (moodTag.toLowerCase()) {
      case 'soiree':
      case 'soirée':
        playlistIds = const ['1934257882', '5964916564'];
        fallbackQuery = 'party hits';
        break;
      case 'nocturne':
        playlistIds = const ['1083721131', '1807219322'];
        fallbackQuery = 'late night chill';
        break;
      case 'sport':
      case 'workout':
        playlistIds = const ['1459249921', '12593959543'];
        fallbackQuery = 'workout hits';
        break;
      case 'detente':
      case 'détente':
      case 'chill':
        playlistIds = const ['1083721131', '1807219322'];
        fallbackQuery = 'chill hits';
        break;
      case 'focus':
        playlistIds = const ['1807219322', '1083721131'];
        fallbackQuery = 'lofi study';
        break;
      case 'trajet':
        playlistIds = const ['2251726662', '1602108955'];
        fallbackQuery = 'roadtrip hits';
        break;
      default:
        fallbackQuery = moodTag;
    }

    if (playlistIds.isNotEmpty) {
      final curated = await _interleavePlaylists(
        playlistIds,
        perPlaylist: 18,
        limit: limit,
      );
      if (curated.isNotEmpty) return curated;
    }

    final playlistTracks = await getContextualTracks(fallbackQuery, limit: limit);
    if (playlistTracks.isNotEmpty) {
      return playlistTracks;
    }
    return searchTracks(query: fallbackQuery, limit: limit);
  }

  // Helper pour récupérer les sons d'une playlist thématique via Deezer
  Future<List<TrackModel>> _getTracksFromPlaylistSearch(String playlistQuery, {int limit = 30}) async {
    try {
      final dioClient = _externalDio;
      final searchRes = await dioClient.get(
        'https://api.deezer.com/search/playlist?q=${Uri.encodeComponent(playlistQuery)}&limit=3',
      );
      if (searchRes.statusCode == 200 &&
          searchRes.data['data'] != null &&
          (searchRes.data['data'] as List).isNotEmpty) {
        for (final item in (searchRes.data['data'] as List)) {
          final playlistId = item['id'];
          final tracks = await getPlaylistTracksDeezer(playlistId, limit: limit);
          if (tracks.isNotEmpty) return tracks;
        }
      }
    } catch (e) {
      print('_getTracksFromPlaylistSearch error: $e');
    }
    return searchTracks(query: playlistQuery, limit: limit);
  }

  // 1.4 Afrobeats 100% Uniquement (Éditorial officiel Deezer Afro)
  Future<List<TrackModel>> getAfrobeatsPureTracks({int limit = 25}) async {
    // Playlist officielle Deezer Afro Editor (ID: 3153080842)
    final tracks = await getPlaylistTracksDeezer('3153080842', limit: limit);
    if (tracks.isNotEmpty) return tracks;
    final fallbackTracks = await getPlaylistTracksDeezer('9654483142', limit: limit);
    if (fallbackTracks.isNotEmpty) return fallbackTracks;
    return _getTracksFromPlaylistSearch('Afrobeats Hits', limit: limit);
  }

  // 1.5 🇨🇲 Top Cameroun (Hits vérifiés du 237)
  Future<List<TrackModel>> getCameroonTopTracks({int limit = 25}) async {
    // Playlist "CAMEROUN URBAN HITS" (ID: 7604783402 - Stanley Enow, Libianca, Kameni, Locko...)
    final urbanTracks = await getPlaylistTracksDeezer('7604783402', limit: limit);
    if (urbanTracks.isNotEmpty) return urbanTracks;
    // Playlist "MBOLE CAMEROUN" (ID: 11399451204)
    final mboleTracks = await getPlaylistTracksDeezer('11399451204', limit: limit);
    if (mboleTracks.isNotEmpty) return mboleTracks;
    return _getTracksFromPlaylistSearch('Hits Cameroun 237', limit: limit);
  }

  // 1.6 🇺🇸 Top 20 USA (Classement officiel Deezer Charts US)
  Future<List<TrackModel>> getTopUsaTracks({int limit = 20}) async {
    // Playlist officielle Deezer Charts "Top USA" (ID: 1313621735 - 608 000+ fans)
    final tracks = await getPlaylistTracksDeezer('1313621735', limit: limit);
    if (tracks.isNotEmpty) return tracks;
    return _getTracksFromPlaylistSearch('Top USA Billboard', limit: limit);
  }

  // 1.7 Tops par Continent (Afrique, Europe, Amérique Latine, Asie & Océanie)
  Future<List<TrackModel>> getContinentalChart(String continentKey, {int limit = 30}) async {
    switch (continentKey) {
      case 'africa':
        // Exclure les sons déjà dans "100% Afrobeats Uniquement" (3153080842)
        final afrobeatsPure = await getPlaylistTracksDeezer('3153080842', limit: 35)
            .catchError((_) => <TrackModel>[]);
        final excludeIds = afrobeatsPure.map((t) => t.id).toSet();
        final excludeKeys = afrobeatsPure
            .map((t) => '${t.title.toLowerCase()}__${t.artistName.toLowerCase()}')
            .toSet();
        // Playlists officielles Deezer Charts Côte d'Ivoire, Sénégal, Nigéria, Hits Afrique Francophone, Amapiano & Cameroun
        final africaChart = await _interleavePlaylists(
          const [
            '1362497945', // Top Ivory Coast (Deezer Charts)
            '1362523075', // Top Senegal (Deezer Charts)
            '11797099761', // Hits Afrique Francophone (Filtr France)
            '5964916564', // Amapiano Finest (Deezer Afro Editor)
            '7604783402', // Cameroun Urban Hits
            '1362516565', // Top Nigeria (Deezer Charts)
          ],
          perPlaylist: 12,
          limit: limit,
          excludeIds: excludeIds,
          excludeTitleKeys: excludeKeys,
        );
        if (africaChart.isNotEmpty) return africaChart;
        return _getTracksFromPlaylistSearch('Hits Afrique Francophone', limit: limit);
      case 'europe':
        // Playlists officielles Deezer Charts Europe (France, UK, Allemagne, Espagne, Italie, Belgique)
        final euChart = await _interleavePlaylists(
          const [
            '1109890291', // Top France
            '1111142221', // Top UK
            '1111143121', // Top Germany
            '1116190041', // Top Spain
            '1116187241', // Top Italy
            '1266968331', // Top Belgium
          ],
          perPlaylist: 10,
          limit: limit,
        );
        if (euChart.isNotEmpty) return euChart;
        return _getTracksFromPlaylistSearch('Top France', limit: limit);
      case 'latam':
        // Playlists officielles Deezer Charts Amérique Latine (Brésil, Mexique, Costa Rica)
        final latamChart = await _interleavePlaylists(
          const [
            '1111141961', // Top Brazil
            '1111142361', // Top Mexico
            '1313618455', // Top Costa Rica
          ],
          perPlaylist: 15,
          limit: limit,
        );
        if (latamChart.isNotEmpty) return latamChart;
        return _getTracksFromPlaylistSearch('Top Latino', limit: limit);
      case 'asia':
        // Playlists officielles Deezer Charts Asie & Océanie (Japon, Corée du Sud, Australie)
        final asiaChart = await _interleavePlaylists(
          const [
            '1362508955', // Top Japan
            '1362510315', // Top South Korea
            '1313616925', // Top Australia
          ],
          perPlaylist: 15,
          limit: limit,
        );
        if (asiaChart.isNotEmpty) return asiaChart;
        return _getTracksFromPlaylistSearch('Top Japan', limit: limit);
      default:
        return getTrendingTracks(limit: limit);
    }
  }

  // 2. Découvertes & Nouvelles Pépites (distinct du Top 50 Worldwide 3155776842)
  Future<List<TrackModel>> getRecentTrends({int limit = 50}) async {
    try {
      final discoveries = await _interleavePlaylists(
        const [
          '1389164505', // Découvertes (Deezer Editors)
          '1282495565', // Radar Weekly (Deezer Editors)
          '1602108955', // Futurs Hits (Deezer Editors)
          '1478649355', // Les nouveautés du vendredi (Deezer Editors)
          '2228601362', // Fresh Pop (Deezer Editors)
        ],
        perPlaylist: 15,
        limit: limit,
      );
      if (discoveries.isNotEmpty) return discoveries;
    } catch (e) {
      print('getRecentTrends error: $e');
    }
    return searchTracks(query: 'fresh hits discoveries', limit: limit);
  }

  // 2.1 Mix Énergique (Playlists officielles Sport, Running & Mood Booster)
  Future<List<TrackModel>> getEnergeticMixTracks({int limit = 25}) async {
    try {
      final energetic = await _interleavePlaylists(
        const [
          '1459249921', // La playlist pour courir (Deezer Dance Editor)
          '1934257882', // mood booster (Deezer Moods Editor)
          '12593959543', // Power Sport Hits (Deezer Editor)
        ],
        perPlaylist: 15,
        limit: limit,
      );
      if (energetic.isNotEmpty) return energetic;
    } catch (e) {
      print('getEnergeticMixTracks error: $e');
    }
    return searchTracks(query: 'workout energy hits', limit: limit);
  }

  // 3. Top Artistes (Récupération dynamique via Deezer API)
  Future<List<Map<String, String>>> getTopArtists({int limit = 20}) async {
    try {
      final dioClient = _externalDio;
      final response = await dioClient.get('https://api.deezer.com/chart/0/artists?limit=$limit');
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['data'] != null && data['data'] is List) {
          final artistsList = data['data'] as List;
          return artistsList.map((artist) {
            return {
              'name': (artist['name'] ?? '').toString(),
              'imageUrl': (artist['picture_medium'] ?? artist['picture'] ?? '').toString(),
            };
          }).toList();
        }
      }
      return [];
    } catch (e) {
      print('getTopArtists error: $e');
      return [];
    }
  }

  // 4. Meilleurs sons d'un artiste
  Future<List<TrackModel>> getArtistTopTracks(String artistName, {int limit = 20}) async {
    try {
      final dioClient = _externalDio;
      final response = await dioClient.get('https://api.deezer.com/search/track?q=${Uri.encodeComponent(artistName)}&limit=$limit');
      if (response.statusCode == 200 && response.data['data'] != null) {
        final data = response.data['data'] as List;
        return data.map((t) => _mapDeezerTrack(t as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      print('getArtistTopTracks error: $e');
    }
    return [];
  }

  // 5. Recommandations hybrides basées sur le profil actif de l'utilisateur
  Future<List<TrackModel>> getRecommendations(
    List<String> favoriteArtists, {
    int limit = 15,
    UserTasteProfile? profile,
  }) async {
    final effectiveProfile = profile ??
        RecommendationEngine.buildProfile(
          selectedArtists: favoriteArtists,
          superlikedTracks: const [],
          favoriteTracks: const [],
          favoriteAlbumArtists: const [],
          recentLocalEntries: const [],
          historyTracks: const [],
          searchedArtists: const [],
        );

    final anchors = effectiveProfile.topAnchorArtists.isNotEmpty
        ? effectiveProfile.topAnchorArtists.take(4).toList()
        : favoriteArtists.take(4).toList();

    if (anchors.isEmpty) {
      return getEnergeticMixTracks(limit: limit);
    }

    try {
      final List<TrackModel> pool = [];
      final futures = <Future<void>>[];

      for (final artist in anchors.take(3)) {
        futures.add(() async {
          try {
            final top = await getArtistTopTracks(artist, limit: 8);
            pool.addAll(top);
          } catch (_) {}
          try {
            final similar = await getSimilarTracks(artist, limit: 8);
            pool.addAll(similar);
          } catch (_) {}
        }());
      }

      for (final family in effectiveProfile.dominantFamilies.take(2)) {
        final seed = _familySearchSeed(family);
        if (seed != null) {
          futures.add(() async {
            try {
              final familyTracks = await searchTracks(query: seed, limit: 12);
              pool.addAll(familyTracks);
            } catch (_) {}
          }());
        }
      }

      await Future.wait(futures);
      if (pool.isNotEmpty) {
        final ranked = RecommendationEngine.rankTracksForProfile(
          pool,
          effectiveProfile,
          limit: limit,
          maxPerArtist: 2,
          strictGate: true,
        );
        if (ranked.isNotEmpty) return ranked;
        final relaxed = RecommendationEngine.rankTracksForProfile(
          pool,
          effectiveProfile,
          limit: limit,
          maxPerArtist: 3,
          strictGate: false,
        );
        if (relaxed.isNotEmpty) return relaxed;
      }
      return getEnergeticMixTracks(limit: limit);
    } catch (e) {
      print('getRecommendations error: $e');
      return getEnergeticMixTracks(limit: limit);
    }
  }

  String? _familySearchSeed(TasteFamily family) {
    switch (family) {
      case TasteFamily.classical:
        return 'classical piano orchestra essentials';
      case TasteFamily.chanson:
        return 'grande chanson francaise classiques';
      case TasteFamily.jazzSoul:
        return 'timeless jazz soul classics';
      case TasteFamily.popRock:
        return 'best pop rock classics hits';
      case TasteFamily.rnb:
        return 'rnb soul essentials';
      case TasteFamily.hipHop:
        return 'rap hip hop essentials';
      case TasteFamily.afro:
        return 'afrobeats hits essential';
      case TasteFamily.electro:
        return 'electronic chill melodic house';
      case TasteFamily.latinWorld:
        return 'latin world acoustic classics';
    }
  }

  /// Génère une playlist personnalisée (10 à 15 sons) selon 1 à 3 émotions
  /// sélectionnées dans Sonoritiz Moods ET les goûts musicaux du compte actif.
  Future<List<TrackModel>> generateMoodEmotionPlaylist({
    required List<String> emotions,
    required UserTasteProfile profile,
    int minTracks = 10,
    int maxTracks = 15,
  }) async {
    final queries = RecommendationEngine.buildEmotionQueries(
      selectedEmotions: emotions,
      profile: profile,
    );
    if (queries.isEmpty) return [];

    final List<TrackModel> candidates = [];
    await Future.wait(queries.take(6).map((q) async {
      try {
        final tracks = await searchTracks(query: q, limit: 10);
        candidates.addAll(tracks);
      } catch (_) {}
    }));

    var ranked = RecommendationEngine.rankTracksForProfile(
      candidates,
      profile,
      limit: maxTracks,
      maxPerArtist: 2,
      strictGate: true,
    );

    if (ranked.length < minTracks) {
      final extraQueries = <String>[];
      for (final emo in emotions) {
        final spec = RecommendationEngine.findEmotionSpec(emo);
        if (spec != null) {
          extraQueries.addAll(spec.deezerMoodQueries.take(2));
        }
      }
      await Future.wait(extraQueries.take(4).map((q) async {
        try {
          final tracks = await searchTracks(query: q, limit: 10);
          candidates.addAll(tracks);
        } catch (_) {}
      }));
      ranked = RecommendationEngine.rankTracksForProfile(
        candidates,
        profile,
        limit: maxTracks,
        maxPerArtist: 3,
        strictGate: profile.artistWeights.length >= 2,
      );
      if (ranked.length < minTracks) {
        ranked = RecommendationEngine.rankTracksForProfile(
          candidates,
          profile,
          limit: maxTracks,
          maxPerArtist: 3,
          strictGate: false,
        );
      }
    }

    return ranked.take(maxTracks).toList();
  }

  // 6. Quiz Musical (Mix varié : Hits mondiaux, francophones, afro avec extraits audio 30s certifiés)
  Future<List<TrackModel>> getQuizTracks({int limit = 35}) async {
    try {
      final dioClient = _externalDio;
      // Charger simultanément les hits mondiaux et les hits francophones/afro
      final chartFuture = dioClient.get('https://api.deezer.com/chart/0/tracks?limit=25');
      final frenchFuture = dioClient.get('https://api.deezer.com/playlist/3155776842/tracks?limit=25');

      final responses = await Future.wait([
        chartFuture.catchError((_) => dio_pkg.Response(requestOptions: dio_pkg.RequestOptions())),
        frenchFuture.catchError((_) => dio_pkg.Response(requestOptions: dio_pkg.RequestOptions())),
      ]);

      final List<TrackModel> collected = [];
      final Set<String> seenTitles = {};

      for (final res in responses) {
        if (res.statusCode == 200 && res.data != null && res.data['data'] is List) {
          for (final item in (res.data['data'] as List)) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final preview = (map['preview'] ?? '').toString().trim();
              final title = (map['title_short'] ?? map['title'] ?? '').toString().trim();
              if (preview.isNotEmpty && title.isNotEmpty && !seenTitles.contains(title.toLowerCase())) {
                seenTitles.add(title.toLowerCase());
                collected.add(_mapDeezerTrack(map));
              }
            }
          }
        }
      }

      if (collected.length >= 10) {
        collected.shuffle();
        return collected.take(limit).toList();
      }
    } catch (e) {
      print('getQuizTracks error: $e');
    }
    return getTrendingTracks(limit: limit);
  }

  // 6.1 Recommandations Contextuelles
  Future<List<TrackModel>> getContextualTracks(String mood, {int limit = 15}) async {
    final normalized = mood.trim().toLowerCase();
    if (const {
      'soiree',
      'soirée',
      'nocturne',
      'sport',
      'workout',
      'detente',
      'détente',
      'chill',
      'focus',
      'trajet',
    }.contains(normalized)) {
      return getTracksByMood(normalized, limit: limit);
    }
    try {
      final dioClient = _externalDio;
      // 1. Chercher des playlists qui correspondent au "mood" (ex: "chill hits", "party hits")
      final playlistResponse = await dioClient.get(
        'https://api.deezer.com/search/playlist?q=${Uri.encodeComponent(mood)}&limit=3',
      );
      
      if (playlistResponse.statusCode == 200 &&
          playlistResponse.data['data'] != null &&
          (playlistResponse.data['data'] as List).isNotEmpty) {
        for (final item in (playlistResponse.data['data'] as List)) {
          final playlistId = item['id'];
          final tracksResponse = await dioClient.get(
            'https://api.deezer.com/playlist/$playlistId/tracks?limit=$limit',
          );
          if (tracksResponse.statusCode == 200 && tracksResponse.data['data'] != null) {
            final data = tracksResponse.data['data'] as List;
            final mapped = data.map((t) => _mapDeezerTrack(t as Map<String, dynamic>)).toList();
            if (mapped.isNotEmpty) return mapped;
          }
        }
      }
    } catch (e) {
      print('getContextualTracks error: $e');
    }
    return [];
  }

  // 6.2 "Parce que vous écoutez X" (Recherche de sons similaires via artistes liés Deezer)
  Future<List<TrackModel>> getSimilarTracks(String artistName, {int limit = 20}) async {
    try {
      final dioClient = _externalDio;
      final cleanName = artistName.split(RegExp(r',|&|feat\.|ft\.', caseSensitive: false)).first.trim();
      final searchArtist = cleanName.isNotEmpty ? cleanName : artistName;
      final artistResponse = await dioClient.get('https://api.deezer.com/search/artist?q=${Uri.encodeComponent(searchArtist)}&limit=1');
      if (artistResponse.statusCode == 200 &&
          artistResponse.data is Map &&
          artistResponse.data['data'] != null &&
          (artistResponse.data['data'] as List).isNotEmpty) {
        final artistId = artistResponse.data['data'][0]['id'];

        final relatedResponse = await dioClient.get('https://api.deezer.com/artist/$artistId/related?limit=6');
        if (relatedResponse.statusCode == 200 &&
            relatedResponse.data is Map &&
            relatedResponse.data['data'] is List) {
          final relatedArtists = (relatedResponse.data['data'] as List).whereType<Map>().toList();
          if (relatedArtists.isNotEmpty) {
            final int perArtist = (limit / relatedArtists.length).ceil() + 3;
            final batches = await Future.wait(
              relatedArtists.map((related) async {
                try {
                  final tracksResponse = await dioClient.get(
                    'https://api.deezer.com/artist/${related['id']}/top?limit=$perArtist',
                  );
                  if (tracksResponse.statusCode == 200 &&
                      tracksResponse.data is Map &&
                      tracksResponse.data['data'] is List) {
                    return (tracksResponse.data['data'] as List)
                        .whereType<Map<String, dynamic>>()
                        .map(_mapDeezerTrack)
                        .toList();
                  }
                } catch (_) {}
                return <TrackModel>[];
              }),
            );

            final List<TrackModel> results = [];
            final Set<String> seenIds = {};
            for (final list in batches) {
              for (final t in list) {
                if (seenIds.add(t.id)) {
                  results.add(t);
                }
              }
            }
            results.shuffle();
            if (results.isNotEmpty) {
              return results.take(limit).toList();
            }
          }
        }
      }

      return getArtistTopTracks(artistName, limit: limit);
    } catch (e) {
      print('getSimilarTracks error: $e');
      return [];
    }
  }

  // 7. Podcasts & Livres Audio via API catalogue (Recherche complète paginée)
  Future<List<TrackModel>> getPodcasts({
    String query = '',
    String type = 'all', // 'all', 'podcast', 'audiobook'
    int limit = 40,
    int offset = 0,
  }) async {
    final List<TrackModel> results = [];
    final Set<String> seenKeys = {};

    try {
      final dioClient = _externalDio;
      final cleanQuery = query.trim();

      void addPodcastItems(dynamic rawData) {
        if (rawData is! List) return;
        for (final item in rawData) {
          if (item is! Map) continue;
          final p = Map<String, dynamic>.from(item);
          final title = (p['title'] ?? '').toString().trim();
          if (title.isEmpty) continue;
          final key = 'pod_${p['id']}_${title.toLowerCase()}';
          final titleKey = 't_${title.toLowerCase()}';
          if (seenKeys.contains(key) || seenKeys.contains(titleKey)) continue;
          seenKeys.add(key);
          seenKeys.add(titleKey);

          final desc = (p['description'] ?? '').toString().trim();
          final cleanDesc = desc
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();

          results.add(
            TrackModel(
              id: 'deezer_podcast_${p['id']}',
              title: title,
              artistName: cleanDesc.isNotEmpty ? cleanDesc : 'Podcast Sonoritiz',
              albumName: cleanDesc,
              coverUrl: (p['picture_xl'] ?? p['picture_big'] ?? p['picture_medium'] ?? p['picture'] ?? '').toString(),
              durationSeconds: 0,
              audioUrl: '',
              genre: 'Podcast',
              licenseCcUrl: '',
            ),
          );
        }
      }

      void addBookAlbumItems(dynamic rawData, {bool requireSpokenHint = false}) {
        if (rawData is! List) return;
        for (final item in rawData) {
          if (item is! Map) continue;
          final a = Map<String, dynamic>.from(item);
          final title = (a['title'] ?? '').toString().trim();
          if (title.isEmpty) continue;
          final titleLower = title.toLowerCase();
          final author = (a['artist'] is Map ? a['artist']['name'] : 'Livre audio')?.toString() ?? 'Livre audio';
          final authorLower = author.toLowerCase();
          if (requireSpokenHint) {
            final looksSpoken = titleLower.contains('livre') ||
                titleLower.contains('audio') ||
                titleLower.contains('roman') ||
                titleLower.contains('audiobook') ||
                titleLower.contains('tome') ||
                titleLower.contains('histoire') ||
                titleLower.contains('chapitre') ||
                titleLower.contains('podcast') ||
                authorLower.contains('livre') ||
                authorLower.contains('audiobook') ||
                authorLower.contains('édition') ||
                authorLower.contains('editions');
            if (!looksSpoken) continue;
          }

          final key = 'book_${a['id']}_$titleLower';
          final titleKey = 't_$titleLower';
          if (seenKeys.contains(key) || seenKeys.contains(titleKey)) continue;
          seenKeys.add(key);
          seenKeys.add(titleKey);

          results.add(
            TrackModel(
              id: 'deezer_book_${a['id']}',
              title: title,
              artistName: author,
              albumName: title,
              coverUrl: (a['cover_xl'] ?? a['cover_big'] ?? a['cover_medium'] ?? a['cover'] ?? '').toString(),
              durationSeconds: 0,
              audioUrl: '',
              genre: 'Livre audio',
              licenseCcUrl: '',
            ),
          );
        }
      }

      final futures = <Future<void>>[];

      // 1. Podcasts (/search/podcast ou /chart/0/podcasts)
      if (type == 'all' || type == 'podcast') {
        final String podcastUrl = cleanQuery.isEmpty
            ? 'https://api.deezer.com/chart/0/podcasts?limit=$limit&index=$offset'
            : 'https://api.deezer.com/search/podcast?q=${Uri.encodeComponent(cleanQuery)}&limit=$limit&index=$offset';
        futures.add(
          dioClient.get(podcastUrl).then((res) {
            if (res.statusCode == 200 && res.data is Map) {
              addPodcastItems(res.data['data']);
            }
          }).catchError((_) {}),
        );

        // Enrichir "À la une" avec des podcasts sur l'amour & les relations humaines
        if (cleanQuery.isEmpty && offset == 0) {
          futures.add(
            dioClient
                .get('https://api.deezer.com/search/podcast?q=${Uri.encodeComponent('amour couple relations')}&limit=8')
                .then((res) {
              if (res.statusCode == 200 && res.data is Map) {
                addPodcastItems(res.data['data']);
              }
            }).catchError((_) {}),
          );
        }
      }

      // 2. Livres audio & albums parlés (/search/album)
      if (type == 'all' || type == 'audiobook') {
        final String frBookQuery = cleanQuery.isEmpty ? 'livre audio français' : '$cleanQuery livre audio';
        futures.add(
          dioClient
              .get('https://api.deezer.com/search/album?q=${Uri.encodeComponent(frBookQuery)}&limit=$limit&index=$offset')
              .then((res) {
            if (res.statusCode == 200 && res.data is Map) {
              addBookAlbumItems(res.data['data']);
            }
          }).catchError((_) {}),
        );

        if (cleanQuery.isNotEmpty) {
          futures.add(
            dioClient
                .get('https://api.deezer.com/search/album?q=${Uri.encodeComponent('$cleanQuery audiobook')}&limit=${(limit / 2).ceil()}&index=$offset')
                .then((res) {
              if (res.statusCode == 200 && res.data is Map) {
                addBookAlbumItems(res.data['data']);
              }
            }).catchError((_) {}),
          );
          futures.add(
            dioClient
                .get('https://api.deezer.com/search/album?q=${Uri.encodeComponent(cleanQuery)}&limit=${(limit / 2).ceil()}&index=$offset')
                .then((res) {
              if (res.statusCode == 200 && res.data is Map) {
                addBookAlbumItems(
                  res.data['data'],
                  requireSpokenHint: type != 'audiobook',
                );
              }
            }).catchError((_) {}),
          );
        }
      }

      // 3. Recherche directe YouTube en parallèle avec les meilleures sources par thématique
      //    (formats longs >= 8 min : émissions, interviews, vodcasts, créateurs fun, foot, livres audio complets)
      final List<TrackModel> ytVideoEpisodes = [];
      if (!kIsWeb && offset == 0) {
        final String qLower = cleanQuery.toLowerCase();
        List<String> ytQueries;

        if (cleanQuery.isEmpty) {
          ytQueries = [
            'LEGEND Guillaume Pley interview podcast complet',
            'Squeezie Darko MrBeast français vidéo concept complet',
            'After Foot RMC Wiloo Zack Nani football débat complet',
            'podcast amour couple relations histoire vraie épisode complet',
          ];
        } else if (type == 'fun' || qLower.contains('squeezie') || qLower.contains('mrbeast') || qLower.contains('darko')) {
          ytQueries = [
            'Squeezie qui est l imposteur thread vidéo complète',
            'Darko Mcfly Carlito Joyca Mastu concept fun',
            'MrBeast en français Amixem Inoxtag Michou défi',
          ];
        } else if (qLower.contains('foot') || qLower.contains('wiloo') || qLower.contains('rmc')) {
          ytQueries = [
            'After Foot RMC débrief football émission complète',
            'Wiloo analyse football Ligue des Champions documentaire',
            'Zack Nani Roue Libre interview football joueur complet',
            'Pieds Carrés Onze Mondial Téléfoot reportage football',
          ];
        } else if (qLower.contains('amour') || qLower.contains('couple')) {
          ytQueries = [
            'podcast amour couple relations sentimentales témoignage complet',
            'Darko couple amour débat relation histoire vraie',
            'Le coeur sur la table relations amoureuses podcast',
          ];
        } else if (qLower.contains('mehdi') || qLower.contains('cko') || qLower.contains('musique')) {
          ytQueries = [
            'Mehdi Maïzi Le Code interview rap musique complet',
            'CKO podcast interview artiste rap afro complet',
            'Clique interview artiste musique légende complet',
          ];
        } else if (qLower.contains('afrique') || qLower.contains('ouihustle')) {
          ytQueries = [
            'OuiHustle interview entrepreneur afrique parcours complet',
            'Investir au Pays afrique culture société débat complet',
            'histoire empires africains culture documentaire complet',
          ];
        } else if (qLower.contains('crime') || qLower.contains('horreur') || qLower.contains('mcskyz')) {
          ytQueries = [
            'Squeezie thread horreur histoire vraie complet',
            'McSkyz histoire vraie affaire criminelle enquête complet',
            'Hondelatte raconte chroniques criminelles affaire complète',
          ];
        } else if (qLower.contains('underscore') || qLower.contains('business') || qLower.contains('gdiy')) {
          ytQueries = [
            'Underscore_ Micode tech hacker IA émission complète',
            'GDIY Génération Do It Yourself entrepreneur podcast complet',
            'Yomi Denzel Marketing Mania business histoire entreprise',
          ];
        } else if (type == 'audiobook' || qLower.contains('livre')) {
          ytQueries = [
            'livre audio complet français roman best seller',
            'livre audio développement personnel philosophie complet français',
          ];
        } else if (qLower.contains('nota bene') || qLower.contains('histoire')) {
          ytQueries = [
            'Nota Bene histoire documentaire récit complet',
            'Questions d Histoire ARTE documentaire histoire complet',
          ];
        } else if (qLower.contains('science') || qLower.contains('jamy')) {
          ytQueries = [
            'Science Etonnante Balade Mentale espace univers complet',
            'Jamy Epicurieux AstronoGeek science découverte documentaire',
          ];
        } else if (qLower.contains('montreux') || qLower.contains('humour') || qLower.contains('floodcast')) {
          ytQueries = [
            'Montreux Comedy spectacle stand up humour complet',
            'FloodCast Un Bon Moment podcast humour complet',
          ];
        } else if (qLower.contains('précepteur') || qLower.contains('philosophie')) {
          ytQueries = [
            'Le Précepteur philosophie podcast épisode complet',
            'Cyrus North psychologie développement personnel philosophie',
          ];
        } else {
          ytQueries = [
            type == 'audiobook'
                ? '$cleanQuery livre audio complet français'
                : '$cleanQuery podcast interview vidéo complète français',
          ];
        }

        final bool isFunCategory = type == 'fun' ||
            qLower.contains('squeezie') ||
            qLower.contains('mrbeast') ||
            qLower.contains('darko');

        for (final ytQuery in ytQueries) {
          futures.add(
            yt.search.search(ytQuery).timeout(const Duration(seconds: 8)).then((searchResults) {
              for (final v in searchResults.whereType<Video>()) {
                final int durSec = v.duration?.inSeconds ?? 0;
                // Filtre strict : uniquement les formats longs (>= 8 minutes / 480s)
                // pour exclure 100 % des clips musicaux, extraits courts et Shorts
                if (durSec < 480) continue;

                final title = v.title.trim();
                if (title.isEmpty) continue;
                final titleLower = title.toLowerCase();
                final key = 'yt_${v.id.value}';
                final titleKey = 't_$titleLower';
                if (seenKeys.contains(key) || seenKeys.contains(titleKey)) continue;
                seenKeys.add(key);
                seenKeys.add(titleKey);
                final mapped = _mapVideoToTrack(v);
                final isBookHint = type == 'audiobook' ||
                    titleLower.contains('livre') ||
                    titleLower.contains('roman') ||
                    titleLower.contains('audiobook');
                final String genreLabel = isFunCategory
                    ? 'Fun & Vidéo'
                    : (isBookHint ? 'Livre audio Vidéo' : 'Podcast Vidéo');
                ytVideoEpisodes.add(
                  mapped.copyWith(genre: genreLabel),
                );
                if (ytVideoEpisodes.length >= 26) break;
              }
            }).catchError((_) {}),
          );
        }
      }

      await Future.wait(futures);

      if (ytVideoEpisodes.isNotEmpty) {
        // Entrelacer harmonieusement les épisodes vidéo YouTube longs avec le catalogue
        // pour qu'ils soient visibles dès les premières lignes
        final List<TrackModel> merged = [];
        int dIdx = 0;
        int yIdx = 0;
        while (dIdx < results.length || yIdx < ytVideoEpisodes.length) {
          if (yIdx < ytVideoEpisodes.length) {
            merged.add(ytVideoEpisodes[yIdx++]);
          }
          if (dIdx < results.length) {
            merged.add(results[dIdx++]);
          }
          if (dIdx < results.length) {
            merged.add(results[dIdx++]);
          }
        }
        return merged;
      }

      if (results.isNotEmpty) {
        return results;
      }
    } catch (e) {
      print('getPodcasts API error: $e');
    }

    // Fallback YouTube uniquement sur la première page si aucun résultat catalogue (hors Web)
    if (kIsWeb || offset > 0) return [];
    try {
      final searchQuery = query.isEmpty ? 'podcast complet français officiel' : '$query podcast livre audio complet';
      final searchResults = await yt.search
          .search(searchQuery)
          .timeout(const Duration(seconds: 10));
      final videos = searchResults.whereType<Video>().take(limit).toList();
      return videos.map((v) => _mapVideoToTrack(v)).toList();
    } catch (e) {
      print('getPodcasts fallback error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchArtists(String query, {int limit = 10}) async {
    try {
      final dioClient = _externalDio;
      final response = await dioClient.get('https://api.deezer.com/search/artist?q=${Uri.encodeComponent(query)}&limit=$limit');
      
      if (response.statusCode == 200 && response.data['data'] != null) {
        final data = response.data['data'] as List;
        final list = data.map((a) {
          return {
            'id': a['id'],
            'name': a['name'] ?? '',
            'picture': a['picture_xl'] ?? a['picture_big'] ?? a['picture_medium'] ?? a['picture'] ?? '',
            'nb_fan': a['nb_fan'] ?? 0,
            'nb_album': a['nb_album'] ?? 0,
          };
        }).toList();

        // Tri intelligent : correspondance exacte d'abord, puis nombre de fans décroissant
        list.sort((a, b) {
          final String nameA = (a['name'] as String).trim().toLowerCase();
          final String nameB = (b['name'] as String).trim().toLowerCase();
          final String cleanQ = query.trim().toLowerCase();

          final bool exactA = nameA == cleanQ;
          final bool exactB = nameB == cleanQ;
          if (exactA && !exactB) return -1;
          if (!exactA && exactB) return 1;

          final int fansA = a['nb_fan'] is int ? a['nb_fan'] as int : 0;
          final int fansB = b['nb_fan'] is int ? b['nb_fan'] as int : 0;
          return fansB.compareTo(fansA);
        });

        return list;
      }
    } catch (e) {
      print('searchArtists error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> searchAlbums(String query, {int limit = 24}) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return [];
    try {
      final dioClient = _externalDio;
      final response = await dioClient.get(
        'https://api.deezer.com/search/album?q=${Uri.encodeComponent(cleanQ)}&limit=$limit',
      );
      if (response.statusCode == 200 &&
          response.data is Map &&
          response.data['data'] is List) {
        final data = response.data['data'] as List;
        return data
            .whereType<Map>()
            .map((a) {
              final artist = a['artist'] is Map ? a['artist'] as Map : const {};
              return <String, dynamic>{
                'id': a['id'],
                'title': (a['title'] ?? '').toString(),
                'artist_name': (artist['name'] ?? 'Artiste').toString(),
                'cover': (a['cover_xl'] ??
                        a['cover_big'] ??
                        a['cover_medium'] ??
                        a['cover'] ??
                        '')
                    .toString(),
                'nb_tracks': int.tryParse(a['nb_tracks']?.toString() ?? '0') ?? 0,
                'record_type': (a['record_type'] ?? 'album').toString(),
              };
            })
            .where((m) => (m['title'] as String).isNotEmpty && m['id'] != null)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<TrackModel>> searchTracks({String query = '', String genre = '', int limit = 50, int offset = 0}) async {
    try {
      final dioClient = _externalDio;
      final String searchQuery = genre.isNotEmpty ? '$query $genre' : query;
      final response = await dioClient.get('https://api.deezer.com/search/track?q=${Uri.encodeComponent(searchQuery)}&limit=$limit');
      
      if (response.statusCode == 200 && response.data['data'] != null) {
        final data = response.data['data'] as List;
        return data.map((t) => _mapDeezerTrack(t as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      print('searchTracks error: $e');
    }
    return [];
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

  // --- SORTIES ALBUMS DE L'ACCUEIL ---

  static final RegExp _releaseArtistSplitRegExp = RegExp(
    r'\s*(?:\bfeat\.?|\bft\.?|\bfeaturing\b|\bwith\b|\bavec\b|&|,|\bx\b)\s*',
    caseSensitive: false,
  );

  /// Ne garde que l'artiste principal, sans les suffixes YouTube (VEVO, Topic...).
  String _cleanReleaseArtistQuery(String raw) {
    return raw
        .replaceAll(RegExp(r'(VEVO| - Topic| Topic| Official| Channel)', caseSensitive: false), '')
        .split(_releaseArtistSplitRegExp)
        .first
        .replaceAll(RegExp(r'[\(\)\[\]]'), '')
        .trim();
  }

  DateTime? _parseReleaseDate(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty || s.startsWith('0000')) return null;
    return DateTime.tryParse(s);
  }

  /// Clé de dédoublonnage : titre sans mentions entre parenthèses (Deluxe, Edition...) + artiste.
  String _albumDedupKey(String title, String artist) {
    final cleanTitle = title
        .toLowerCase()
        .replaceAll(RegExp(r'[\(\[][^\)\]]*[\)\]]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${cleanTitle}__${artist.toLowerCase().trim()}';
  }

  /// Recherche l'artiste sur Deezer en privilégiant le nom exact parmi 5 résultats.
  Future<Map<String, dynamic>?> _findDeezerArtistForReleases(String artistName) async {
    final query = _cleanReleaseArtistQuery(artistName);
    if (query.length < 2) return null;
    final res = await _externalDio.get(
      'https://api.deezer.com/search/artist?q=${Uri.encodeComponent(query)}&limit=5',
    );
    if (res.statusCode != 200 || res.data is! Map || res.data['data'] is! List) return null;
    final list = (res.data['data'] as List).whereType<Map>().toList();
    if (list.isEmpty) return null;
    final target = query.toLowerCase();

    // 1re passe : nom exact
    for (final a in list) {
      if ((a['name'] ?? '').toString().toLowerCase().trim() == target) {
        return Map<String, dynamic>.from(a);
      }
    }
    // 2e passe : correspondance partielle
    for (final a in list) {
      final name = (a['name'] ?? '').toString().toLowerCase().trim();
      if (name.isNotEmpty && (name.contains(target) || target.contains(name))) {
        return Map<String, dynamic>.from(a);
      }
    }
    return Map<String, dynamic>.from(list.first);
  }

  Map<String, dynamic> _mapReleaseAlbum(
    Map a, {
    required String artistName,
    required String artistPicture,
    required String source,
  }) {
    return {
      'id': a['id'],
      'title': (a['title'] ?? '').toString().trim(),
      'cover': (a['cover_xl'] ?? a['cover_big'] ?? a['cover_medium'] ?? a['cover'] ?? '').toString(),
      'artist_name': artistName,
      'artist_picture': artistPicture,
      'record_type': (a['record_type'] ?? 'album').toString(),
      'release_date': (a['release_date'] ?? '').toString(),
      // 'for_you' = tes artistes • 'related' = artistes similaires • 'trending' = nouveautés du moment
      'source': source,
    };
  }

  /// Sorties d'albums de l'accueil, dans cet ordre :
  /// 1. Sorties récentes des artistes de l'utilisateur ([preferredArtists] doit être trié par priorité)
  /// 2. Sorties récentes d'artistes similaires (via l'endpoint /related de Deezer)
  /// 3. Grosses nouveautés du moment (éditorial Deezer), sans doublons
  Future<List<Map<String, dynamic>>> getPersonalizedNewAlbumReleasesDeezer({
    List<String> preferredArtists = const [],
    int limit = 60,
    int maxArtists = 15,
    int recentDays = 90,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime recentCutoff = now.subtract(Duration(days: recentDays));
    final DateTime olderCutoff = now.subtract(const Duration(days: 365));

    // 1. Artistes cibles (dédoublonnés, ordre de priorité conservé)
    final List<String> targetArtists = [];
    for (final raw in preferredArtists) {
      final clean = _cleanReleaseArtistQuery(raw);
      if (clean.length < 2) continue;
      if (!targetArtists.any((a) => a.toLowerCase() == clean.toLowerCase())) {
        targetArtists.add(clean);
      }
      if (targetArtists.length >= maxArtists) break;
    }

    final List<Map<String, dynamic>> forYouRecent = [];
    final List<Map<String, dynamic>> forYouOlder = [];
    final Map<String, dynamic> resolvedArtistIds = {};

    // Requêtes par lots de 5 en parallèle pour rester rapide sans dépasser le quota Deezer
    for (int i = 0; i < targetArtists.length; i += 5) {
      final int end = (i + 5 < targetArtists.length) ? i + 5 : targetArtists.length;
      final batch = targetArtists.sublist(i, end);
      await Future.wait(batch.map((name) async {
        try {
          final artist = await _findDeezerArtistForReleases(name);
          if (artist == null || artist['id'] == null) return;
          final artistId = artist['id'];
          resolvedArtistIds[name.toLowerCase()] = artistId;
          final realName = (artist['name'] ?? name).toString();
          final picture = (artist['picture_xl'] ?? artist['picture_medium'] ?? '').toString();

          final albumsRes = await _externalDio.get(
            'https://api.deezer.com/artist/$artistId/albums?limit=10',
          );
          if (albumsRes.statusCode != 200 || albumsRes.data is! Map || albumsRes.data['data'] is! List) {
            return;
          }
          for (final a in (albumsRes.data['data'] as List).whereType<Map>()) {
            final date = _parseReleaseDate(a['release_date']);
            if (date == null) continue;
            final mapped = _mapReleaseAlbum(
              a,
              artistName: realName,
              artistPicture: picture,
              source: 'for_you',
            );
            if (date.isAfter(recentCutoff)) {
              forYouRecent.add(mapped);
            } else if (date.isAfter(olderCutoff)) {
              forYouOlder.add(mapped);
            }
          }
        } catch (_) {}
      }));
    }

    // 2. Artistes similaires aux 3 artistes les plus écoutés (1 sortie récente chacun)
    final List<Map<String, dynamic>> relatedRecent = [];
    final Set<String> userArtistIdSet = resolvedArtistIds.values.map((e) => e.toString()).toSet();
    final List<dynamic> topIds = targetArtists
        .take(3)
        .map((n) => resolvedArtistIds[n.toLowerCase()])
        .where((id) => id != null)
        .toList();

    await Future.wait(topIds.map((artistId) async {
      try {
        final relRes = await _externalDio.get(
          'https://api.deezer.com/artist/$artistId/related?limit=4',
        );
        if (relRes.statusCode != 200 || relRes.data is! Map || relRes.data['data'] is! List) return;
        final relList = (relRes.data['data'] as List)
            .whereType<Map>()
            .where((r) => !userArtistIdSet.contains(r['id'].toString()))
            .take(2)
            .toList();

        await Future.wait(relList.map((rel) async {
          try {
            final relAlbumRes = await _externalDio.get(
              'https://api.deezer.com/artist/${rel['id']}/albums?limit=5',
            );
            if (relAlbumRes.statusCode != 200 || relAlbumRes.data is! Map || relAlbumRes.data['data'] is! List) {
              return;
            }
            Map<String, dynamic>? best;
            DateTime? bestDate;
            for (final a in (relAlbumRes.data['data'] as List).whereType<Map>()) {
              final date = _parseReleaseDate(a['release_date']);
              if (date == null || !date.isAfter(recentCutoff)) continue;
              if (bestDate == null || date.isAfter(bestDate)) {
                bestDate = date;
                best = _mapReleaseAlbum(
                  a,
                  artistName: (rel['name'] ?? '').toString(),
                  artistPicture: (rel['picture_xl'] ?? rel['picture_medium'] ?? '').toString(),
                  source: 'related',
                );
              }
            }
            if (best != null) relatedRecent.add(best);
          } catch (_) {}
        }));
      } catch (_) {}
    }));

    // 3. Grosses nouveautés du moment
    final trending = await getNewAlbumReleasesDeezer(limit: 40);

    // 4. Assemblage final par ordre de priorité, sans doublons
    final List<Map<String, dynamic>> result = [];
    final Set<String> seenIds = {};
    final Set<String> seenKeys = {};

    bool addIfNew(Map<String, dynamic> album) {
      final id = album['id']?.toString() ?? '';
      final title = (album['title'] ?? '').toString();
      if (id.isEmpty || title.isEmpty) return false;
      final key = _albumDedupKey(title, (album['artist_name'] ?? '').toString());
      if (seenIds.contains(id) || seenKeys.contains(key)) return false;
      seenIds.add(id);
      seenKeys.add(key);
      result.add(album);
      return true;
    }

    int byDateDesc(Map<String, dynamic> a, Map<String, dynamic> b) =>
        (b['release_date'] ?? '').toString().compareTo((a['release_date'] ?? '').toString());

    forYouRecent.sort(byDateDesc);
    int forYouCount = 0;
    for (final a in forYouRecent) {
      if (addIfNew(a)) forYouCount++;
    }
    // Trop peu de sorties récentes : compléter avec les plus récentes de l'année
    if (forYouCount < 6) {
      forYouOlder.sort(byDateDesc);
      for (final a in forYouOlder) {
        if (forYouCount >= 6) break;
        if (addIfNew(a)) forYouCount++;
      }
    }

    relatedRecent.sort(byDateDesc);
    for (final a in relatedRecent) {
      addIfNew(a);
    }

    // Si l'utilisateur a des artistes/sorties ciblées, filtrer les tendances
    // pour ne pas mêler de genres incompatibles (ex: Rap/Afro chez un profil Classique)
    final preferredProfile = RecommendationEngine.buildProfile(
      selectedArtists: preferredArtists,
      superlikedTracks: const [],
      favoriteTracks: const [],
      favoriteAlbumArtists: const [],
      recentLocalEntries: const [],
      historyTracks: const [],
      searchedArtists: const [],
    );

    if (result.length < 10) {
      for (final a in trending) {
        final date = _parseReleaseDate(a['release_date']);
        if (date != null && !date.isAfter(recentCutoff)) continue;
        if (!preferredProfile.isColdStart && preferredArtists.length >= 2) {
          final candFamily = RecommendationEngine.classifyText(
            '${a['artist_name'] ?? ''} ${a['title'] ?? ''}',
          );
          if (candFamily != null &&
              (preferredProfile.familyScores[candFamily] ?? 0.0) <= 0.0 &&
              result.length >= 4) {
            continue;
          }
        }
        addIfNew(a);
      }
    }

    return result.take(limit).toList();
  }

  /// Grosses nouveautés du moment : sorties officielles Deezer (avec date), puis chart albums en secours.
  Future<List<Map<String, dynamic>>> getNewAlbumReleasesDeezer({int limit = 30}) async {
    final List<Map<String, dynamic>> results = [];
    for (final url in [
      'https://api.deezer.com/editorial/0/releases?limit=$limit',
      'https://api.deezer.com/chart/0/albums?limit=$limit',
    ]) {
      if (results.isNotEmpty) break;
      try {
        final response = await _externalDio.get(url);
        if (response.statusCode == 200 && response.data is Map && response.data['data'] is List) {
          for (final a in (response.data['data'] as List).whereType<Map>()) {
            final artist = a['artist'] is Map ? a['artist'] as Map : const {};
            results.add(_mapReleaseAlbum(
              a,
              artistName: (artist['name'] ?? 'Artiste inconnu').toString(),
              artistPicture: (artist['picture_xl'] ?? artist['picture_medium'] ?? '').toString(),
              source: 'trending',
            ));
          }
        }
      } catch (e) {
        print('getNewAlbumReleasesDeezer error: $e');
      }
    }
    return results;
  }

  Future<String> getArtistBio(String artistName) async {
    final String cleanName = artistName
        .replaceAll(RegExp(r'(VEVO| - Topic| Topic| Official| Channel)', caseSensitive: false), '')
        .trim();
    try {
      final dioClient = _externalDio;
      // 1. Recherche directe par titre Wikipedia FR
      final url =
          'https://fr.wikipedia.org/w/api.php?action=query&prop=extracts&exintro=1&explaintext=1&redirects=1&titles=${Uri.encodeComponent(cleanName)}&format=json';
      final response = await dioClient.get(url);

      if (response.statusCode == 200 && response.data is Map) {
        final pages = response.data['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null && pages.isNotEmpty) {
          final firstPage = pages.values.first;
          if (firstPage is Map && firstPage['extract'] != null) {
            final extract = firstPage['extract'].toString().trim();
            if (extract.length > 40 && !extract.contains("peut faire référence à")) {
              return extract;
            }
          }
        }
      }

      // 2. Fallback : recherche Wikipedia FR ciblée sur l'artiste musical
      final searchUrl =
          'https://fr.wikipedia.org/w/api.php?action=query&list=search&srsearch=${Uri.encodeComponent('$cleanName chanteur OR rappeur OR musicien OR groupe')}&srlimit=1&format=json';
      final searchRes = await dioClient.get(searchUrl);
      if (searchRes.statusCode == 200 && searchRes.data is Map) {
        final results = searchRes.data['query']?['search'] as List?;
        if (results != null && results.isNotEmpty) {
          final pageTitle = results.first['title']?.toString() ?? '';
          if (pageTitle.isNotEmpty) {
            final extractRes = await dioClient.get(
              'https://fr.wikipedia.org/w/api.php?action=query&prop=extracts&exintro=1&explaintext=1&redirects=1&titles=${Uri.encodeComponent(pageTitle)}&format=json',
            );
            if (extractRes.statusCode == 200 && extractRes.data is Map) {
              final pages = extractRes.data['query']?['pages'] as Map<String, dynamic>?;
              if (pages != null && pages.isNotEmpty) {
                final firstPage = pages.values.first;
                final extract = (firstPage['extract'] ?? '').toString().trim();
                if (extract.length > 40 && !extract.contains("peut faire référence à")) {
                  return extract;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('getArtistBio error: $e');
    }

    return "Découvrez l'univers musical, les titres les plus écoutés et la discographie complète de $cleanName.";
  }

  // 7. Générateur de Playlists Intelligentes (Smart Playlists)
  Future<List<TrackModel>> generateSmartPlaylist(String mood, {int limit = 20}) async {
    try {
      final dioClient = _externalDio;
      final response = await dioClient.get('https://api.deezer.com/search/track?q=${Uri.encodeComponent(mood)}&limit=$limit');
      if (response.statusCode == 200 && response.data['data'] != null) {
        final data = response.data['data'] as List;
        return data.map((t) => _mapDeezerTrack(t as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      print('generateSmartPlaylist error: $e');
    }
    return [];
  }

  TrackModel _mapVideoToTrack(Video video) {
    String artist = video.author
        .replaceAll(RegExp(r'\s*(?:VEVO|- Topic|Topic|Official)\s*$', caseSensitive: false), '')
        .trim();
    String title = video.title;

    // Si le titre YouTube est sous la forme "Artiste 1 & Artiste 2 - Titre (feat. X)"
    if (title.contains(' - ')) {
      final parts = title.split(' - ');
      final leftPart = parts.first.trim();
      final rightPart = parts.sublist(1).join(' - ').trim();
      if (leftPart.isNotEmpty && leftPart.length < 60) {
        artist = leftPart;
        title = rightPart;
      }
    }

    // Extraire un éventuel (feat. X) ou ft. X du titre vers artistName
    final RegExp featRegex = RegExp(
      r'[\(\[]?\b(?:feat\.?|ft\.?|featuring)\s+([^\)\]\-\|]+)[\)\]]?',
      caseSensitive: false,
    );
    final match = featRegex.firstMatch(title);
    if (match != null && match.group(1) != null) {
      final featArtist = match.group(1)!.trim();
      if (featArtist.isNotEmpty && !artist.toLowerCase().contains(featArtist.toLowerCase())) {
        artist = '$artist feat. $featArtist';
      }
      title = title.replaceFirst(match.group(0)!, '').trim();
    }

    return TrackModel(
      id: video.id.value,
      title: title,
      artistName: artist,
      albumName: 'YouTube Audio',
      coverUrl: video.thumbnails.highResUrl,
      durationSeconds: video.duration?.inSeconds ?? 0,
      audioUrl: '', // URL résolue à la lecture
      genre: 'YouTube',
      licenseCcUrl: '',
    );
  }

  // --- NOUVELLES METHODES DEEZER ---

  Future<Map<String, dynamic>> getArtistDetailsDeezer(String artistName) async {
    try {
      // Nettoyage du nom pour enlever les suffixes YouTube et ne garder qu'un artiste cible
      String cleanName = artistName
          .replaceAll(RegExp(r'(VEVO| - Topic| Topic| Official| Channel)', caseSensitive: false), '')
          .split(RegExp(r'\s+(?:feat\.?|ft\.?|featuring)\s+', caseSensitive: false))
          .first
          .trim();

      final String queryLower = cleanName.toLowerCase().trim();

      // 0. Vérifier si l'artiste exact a déjà été résolu et enregistré par l'utilisateur lors d'une recherche
      try {
        final recorded = StorageService().getTopSearchedArtists(limit: 30);
        for (final r in recorded) {
          final rName = (r['name'] ?? '').toString().toLowerCase().trim();
          final rId = int.tryParse((r['id'] ?? '').toString()) ?? 0;
          if (rName == queryLower && rId > 0) {
            final byId = await getArtistDetailsDeezerById(rId);
            if (byId.isNotEmpty && (byId['id'] ?? 0) != 0) {
              return byId;
            }
          }
        }
      } catch (_) {}

      final dioClient = _externalDio;
      final searchResponse = await dioClient.get(
        'https://api.deezer.com/search/artist?q=${Uri.encodeComponent(cleanName)}&limit=10',
      );
      if (searchResponse.statusCode == 200 &&
          searchResponse.data['data'] != null &&
          (searchResponse.data['data'] as List).isNotEmpty) {
        final List<Map<String, dynamic>> candidates = (searchResponse.data['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        // Trier par correspondance exacte du nom EN PREMIER, puis par popularité (nb_fan décroissant)
        // pour éviter tout profil homonyme obscur portant le même nom !
        candidates.sort((a, b) {
          final String aName = (a['name'] ?? '').toString().toLowerCase().trim();
          final String bName = (b['name'] ?? '').toString().toLowerCase().trim();
          final bool aExact = aName == queryLower;
          final bool bExact = bName == queryLower;
          if (aExact != bExact) return aExact ? -1 : 1;

          final bool aContains = aName.contains(queryLower) || queryLower.contains(aName);
          final bool bContains = bName.contains(queryLower) || queryLower.contains(bName);
          if (aContains != bContains) return aContains ? -1 : 1;

          final int aFans = (a['nb_fan'] is int)
              ? a['nb_fan'] as int
              : (int.tryParse((a['nb_fan'] ?? '0').toString()) ?? 0);
          final int bFans = (b['nb_fan'] is int)
              ? b['nb_fan'] as int
              : (int.tryParse((b['nb_fan'] ?? '0').toString()) ?? 0);
          return bFans.compareTo(aFans);
        });

        final Map<String, dynamic> bestMatch = candidates.first;
        final artistId = bestMatch['id'];
        final detailsResponse = await dioClient.get('https://api.deezer.com/artist/$artistId');
        if (detailsResponse.statusCode == 200) {
          final details = detailsResponse.data;
          final String realName = (details['name'] ?? cleanName).toString();
          final String bio = await getArtistBio(realName);

          return {
            'id': details['id'],
            'name': realName,
            'picture_xl': details['picture_xl'] ?? details['picture_big'] ?? details['picture_medium'] ?? '',
            'nb_fan': details['nb_fan'] ?? bestMatch['nb_fan'] ?? 0,
            'nb_album': details['nb_album'] ?? bestMatch['nb_album'] ?? 0,
            'bio': bio,
          };
        }
      }
    } catch (e) {
      print('getArtistDetailsDeezer error: $e');
    }
    return {
      'id': 0,
      'name': artistName,
      'picture_xl': '',
      'nb_fan': 0,
      'nb_album': 0,
      'bio': 'Informations non disponibles.',
    };
  }

  /// Récupération directe et exacte des détails d'un artiste via son ID officiel Deezer (0 risque d'homonyme)
  Future<Map<String, dynamic>> getArtistDetailsDeezerById(int artistId) async {
    try {
      if (artistId <= 0) return {};
      final dioClient = _externalDio;
      final detailsResponse = await dioClient.get('https://api.deezer.com/artist/$artistId');
      if (detailsResponse.statusCode == 200 && detailsResponse.data != null) {
        final details = detailsResponse.data;
        final String realName = (details['name'] ?? '').toString();
        final String bio = realName.isNotEmpty ? await getArtistBio(realName) : '';

        return {
          'id': details['id'] ?? artistId,
          'name': realName,
          'picture_xl': details['picture_xl'] ?? details['picture_big'] ?? details['picture_medium'] ?? details['picture'] ?? '',
          'nb_fan': details['nb_fan'] ?? 0,
          'nb_album': details['nb_album'] ?? 0,
          'bio': bio,
        };
      }
    } catch (e) {
      print('getArtistDetailsDeezerById error: $e');
    }
    return {};
  }

  Future<List<TrackModel>> getArtistTopTracksDeezer(int artistId, {int limit = 7}) async {
    try {
      final dioClient = _externalDio;
      final response = await dioClient.get('https://api.deezer.com/artist/$artistId/top?limit=$limit');
      if (response.statusCode == 200 && response.data['data'] != null) {
        final tracksData = response.data['data'] as List;
        return tracksData.map((t) {
          final map = t as Map<String, dynamic>;
          return TrackModel(
            id: 'deezer_${map['id']}',
            title: _cleanDeezerTitle(map),
            artistName: _extractDeezerArtistName(map),
            albumName: map['album']?['title'] ?? '',
            coverUrl: map['album']?['cover_xl'] ?? map['album']?['cover_medium'] ?? '',
            durationSeconds: map['duration'] ?? 0,
            audioUrl: '',
            genre: 'Top Titres',
            licenseCcUrl: '',
          );
        }).toList();
      }
    } catch (e) {
      print('getArtistTopTracksDeezer error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getArtistAlbumsDeezer(int artistId) async {
    try {
      final dioClient = _externalDio;
      final response = await dioClient.get('https://api.deezer.com/artist/$artistId/albums?limit=25');
      if (response.statusCode == 200 && response.data['data'] != null) {
        final albumsData = response.data['data'] as List;
        return albumsData.map((a) {
          return {
            'id': a['id'],
            'title': a['title'] ?? '',
            'cover_xl': a['cover_xl'] ?? a['cover_medium'] ?? '',
            'release_date': a['release_date'] ?? '',
            'record_type': a['record_type'] ?? 'album',
          };
        }).toList();
      }
    } catch (e) {
      print('getArtistAlbumsDeezer error: $e');
    }
    return [];
  }

  /// Artistes similaires officiels via Deezer `/artist/<id>/related`
  Future<List<Map<String, String>>> getRelatedArtistsDeezer(
    int artistId, {
    int limit = 12,
  }) async {
    if (artistId <= 0) return [];
    try {
      final dioClient = _externalDio;
      final response = await dioClient.get(
        'https://api.deezer.com/artist/$artistId/related?limit=$limit',
      );
      if (response.statusCode == 200 && response.data['data'] is List) {
        final list = response.data['data'] as List;
        return list.whereType<Map>().map((a) {
          return <String, String>{
            'id': (a['id'] ?? '').toString(),
            'name': (a['name'] ?? '').toString(),
            'imageUrl': (a['picture_xl'] ??
                    a['picture_big'] ??
                    a['picture_medium'] ??
                    a['picture'] ??
                    '')
                .toString(),
          };
        }).where((m) => (m['name'] ?? '').isNotEmpty).toList();
      }
    } catch (e) {
      print('getRelatedArtistsDeezer error: $e');
    }
    return [];
  }

  /// Radio / Mix continu autour d'un artiste via Deezer `/artist/<id>/radio`
  Future<List<TrackModel>> getArtistRadioTracksDeezer(
    int artistId, {
    int limit = 25,
  }) async {
    if (artistId <= 0) return [];
    try {
      final dioClient = _externalDio;
      final response = await dioClient.get(
        'https://api.deezer.com/artist/$artistId/radio?limit=$limit',
      );
      if (response.statusCode == 200 && response.data['data'] is List) {
        final list = response.data['data'] as List;
        return list
            .whereType<Map>()
            .map((t) => _mapDeezerTrack(Map<String, dynamic>.from(t)))
            .toList();
      }
    } catch (e) {
      print('getArtistRadioTracksDeezer error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getAlbumDetailsDeezer(int albumId) async {
    try {
      final dioClient = _externalDio;
      final response = await dioClient.get('https://api.deezer.com/album/$albumId');
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      print('getAlbumDetailsDeezer error: $e');
    }
    return null;
  }

  Future<List<TrackModel>> getAlbumTracksDeezer(
    int albumId,
    String albumCover,
    String artistName, {
    String albumTitle = '',
  }) async {
    try {
      final dioClient = _externalDio;
      final response = await dioClient.get('https://api.deezer.com/album/$albumId/tracks');
      if (response.statusCode == 200 && response.data['data'] != null) {
        final tracksData = response.data['data'] as List;
        return tracksData.map((t) {
          final map = t as Map<String, dynamic>;
          return TrackModel(
            id: 'deezer_${map['id']}',
            title: _cleanDeezerTitle(map),
            artistName: _extractDeezerArtistName(map, fallbackArtist: artistName),
            albumName: albumTitle.isNotEmpty ? albumTitle : (map['album']?['title'] ?? ''),
            coverUrl: albumCover,
            durationSeconds: map['duration'] ?? 0,
            audioUrl: (map['preview'] ?? '').toString(),
            genre: 'Album Studio',
            licenseCcUrl: '',
          );
        }).toList();
      }
    } catch (e) {
      print('getAlbumTracksDeezer error: $e');
    }
    return [];
  }

  /// 4.0 Albums & Sons à venir & Nouvelles Sorties officielles Deezer
  Future<List<Map<String, dynamic>>> getUpcomingAndNewReleases({int limit = 15}) async {
    try {
      final dioClient = _externalDio;
      // 1. Tenter les sorties éditoriales fraîches Deezer (/editorial/0/releases)
      final res = await dioClient.get('https://api.deezer.com/editorial/0/releases?limit=$limit');
      if (res.statusCode == 200 && res.data['data'] != null && (res.data['data'] as List).isNotEmpty) {
        final list = res.data['data'] as List;
        return list.map((a) {
          final map = a as Map<String, dynamic>;
          return {
            'id': map['id'],
            'title': (map['title'] ?? 'Nouvelle Sortie').toString(),
            'artist': (map['artist']?['name'] ?? 'Artiste').toString(),
            'artist_id': map['artist']?['id']?.toString(),
            'cover': (map['cover_xl'] ?? map['cover_big'] ?? map['cover_medium'] ?? map['cover'] ?? '').toString(),
            'release_date': (map['release_date'] ?? '').toString(),
            'nb_tracks': int.tryParse(map['nb_tracks']?.toString() ?? '0') ?? 0,
            'is_upcoming': true,
          };
        }).toList();
      }
    } catch (_) {}

    // Fallback : albums phares du chart Deezer
    try {
      final dioClient = _externalDio;
      final res = await dioClient.get('https://api.deezer.com/chart/0/albums?limit=$limit');
      if (res.statusCode == 200 && res.data['data'] != null) {
        final list = res.data['data'] as List;
        return list.map((a) {
          final map = a as Map<String, dynamic>;
          return {
            'id': map['id'],
            'title': (map['title'] ?? 'Album').toString(),
            'artist': (map['artist']?['name'] ?? 'Artiste').toString(),
            'artist_id': map['artist']?['id']?.toString(),
            'cover': (map['cover_xl'] ?? map['cover_big'] ?? map['cover_medium'] ?? map['cover'] ?? '').toString(),
            'release_date': (map['release_date'] ?? '').toString(),
            'nb_tracks': int.tryParse(map['nb_tracks']?.toString() ?? '0') ?? 0,
            'is_upcoming': false,
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static const String _genresCacheKey = 'sonoritiz_genres_cache_v1';

  Future<List<Map<String, dynamic>>> getCachedDeezerGenres() async {
    try {
      final raw = await JsonCache.read(_genresCacheKey);
      if (raw is List) {
        return raw.whereType<Map>().map((e) {
          final m = Map<String, dynamic>.from(e);
          final cVal = m['color_value'];
          if (cVal is int) {
            m['color'] = Color(cVal);
          } else {
            m['color'] = _getColorForGenre((m['name'] ?? '').toString());
          }
          return m;
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  /// 4.1 Tous les genres musicaux officiels proposés par l'API catalogue
  Future<List<Map<String, dynamic>>> getAllDeezerGenres() async {
    try {
      final dioClient = _externalDio;
      final res = await dioClient.get('https://api.deezer.com/genre');
      if (res.statusCode == 200 && res.data['data'] != null) {
        final list = res.data['data'] as List;
        final mapped = list
            .where((g) => (g['id'] ?? 0) != 0) // Exclure l'entrée 'All' (ID 0)
            .map((g) {
              final map = g as Map<String, dynamic>;
              final name = (map['name'] ?? '').toString();
              final color = _getColorForGenre(name);
              return {
                'id': map['id'],
                'title': name,
                'name': name,
                'query': name,
                'image': (map['picture_xl'] ?? map['picture_big'] ?? map['picture_medium'] ?? map['picture'] ?? '').toString(),
                'color': color,
                'color_value': color.toARGB32(),
              };
            })
            .toList();

        if (mapped.isNotEmpty) {
          await JsonCache.write(
            _genresCacheKey,
            mapped
                .map((m) => {
                      'id': m['id'],
                      'title': m['title'],
                      'name': m['name'],
                      'query': m['query'],
                      'image': m['image'],
                      'color_value': m['color_value'],
                    })
                .toList(),
          );
        }
        return mapped;
      }
    } catch (e) {
      print('getAllDeezerGenres error: $e');
    }
    return getCachedDeezerGenres();
  }

  /// 4.2 Récupère les morceaux du Top d'un genre spécifique (avec secours artistes du genre / recherche)
  Future<List<TrackModel>> getTracksByGenreId(
    dynamic genreId, {
    String? genreName,
    int limit = 30,
  }) async {
    final dioClient = _externalDio;
    try {
      final res = await dioClient.get('https://api.deezer.com/chart/$genreId/tracks?limit=$limit');
      if (res.statusCode == 200 &&
          res.data is Map &&
          res.data['data'] != null &&
          (res.data['data'] as List).isNotEmpty) {
        final list = res.data['data'] as List;
        return list.map((t) => _mapDeezerTrack(t as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    // 2. Beaucoup de genres Deezer n'ont pas de /chart/{id}/tracks mais ont /genre/{id}/artists
    try {
      final artistsRes = await dioClient.get('https://api.deezer.com/genre/$genreId/artists?limit=6');
      if (artistsRes.statusCode == 200 &&
          artistsRes.data is Map &&
          artistsRes.data['data'] is List &&
          (artistsRes.data['data'] as List).isNotEmpty) {
        final artists = (artistsRes.data['data'] as List).whereType<Map>().take(6).toList();
        final topBatches = await Future.wait(
          artists.map((a) async {
            try {
              final id = a['id'];
              if (id == null) return <TrackModel>[];
              return await getArtistTopTracksDeezer(int.parse(id.toString()), limit: 6);
            } catch (_) {
              return <TrackModel>[];
            }
          }),
        );
        final List<TrackModel> combined = [];
        final Set<String> seenIds = {};
        for (final batch in topBatches) {
          for (final t in batch) {
            if (seenIds.add(t.id)) combined.add(t);
          }
        }
        if (combined.isNotEmpty) {
          return combined.take(limit).toList();
        }
      }
    } catch (_) {}

    final cleanGenre = (genreName ?? '').trim();
    if (cleanGenre.isNotEmpty) {
      final playlistTracks = await _getTracksFromPlaylistSearch(cleanGenre, limit: limit);
      if (playlistTracks.isNotEmpty) return playlistTracks;
      return searchTracks(query: cleanGenre, limit: limit);
    }
    return [];
  }

  Color _getColorForGenre(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('pop')) return const Color(0xFFFF4081);
    if (lower.contains('rap') || lower.contains('hip hop')) return const Color(0xFF7C4DFF);
    if (lower.contains('rock') || lower.contains('metal')) return const Color(0xFFE040FB);
    if (lower.contains('r&b') || lower.contains('soul')) return const Color(0xFFFF5252);
    if (lower.contains('afro') || lower.contains('african')) return const Color(0xFFFF6D00);
    if (lower.contains('electro') || lower.contains('dance')) return const Color(0xFF00E676);
    if (lower.contains('latin')) return const Color(0xFFFFAB00);
    if (lower.contains('reggae')) return const Color(0xFF00BFA5);
    if (lower.contains('jazz') || lower.contains('blues')) return const Color(0xFF2979FF);
    if (lower.contains('class') || lower.contains('ambient')) return const Color(0xFF536DFE);
    return const Color(0xFFFF5500);
  }

  /// 4.3 Algorithme personnalisé : Génération parallèle des 5 playlists sur-mesure (30 sons chacune)
  Future<List<Map<String, dynamic>>> generateWeeklyCuratedPlaylists({
    List<String> topArtists = const [],
    List<String> topKeywords = const [],
    UserTasteProfile? tasteProfile,
  }) async {
    const List<int> accentColors = [
      0xFFFF6D00,
      0xFF8E2DE2,
      0xFFFF1744,
      0xFF00BFA5,
      0xFFFFB300,
    ];

    final effectiveProfile = tasteProfile ??
        RecommendationEngine.buildProfile(
          selectedArtists: topArtists,
          superlikedTracks: const [],
          favoriteTracks: const [],
          favoriteAlbumArtists: const [],
          recentLocalEntries: const [],
          historyTracks: const [],
          searchedArtists: const [],
        );

    final List<String> cleanArtists = [];
    final Set<String> seenArtists = {};
    final anchorPool = [
      ...effectiveProfile.topAnchorArtists,
      ...topArtists,
    ];
    for (final raw in anchorPool) {
      final clean = raw
          .split(RegExp(r',|&|\bfeat\.?|\bft\.?', caseSensitive: false))
          .first
          .trim();
      if (clean.length < 2) continue;
      if (seenArtists.add(clean.toLowerCase())) {
        cleanArtists.add(clean);
      }
      if (cleanArtists.length >= 5) break;
    }

    final List<Map<String, String>> dynamicThemes = _buildCuratedThemesForProfile(effectiveProfile);

    const List<String> personalPrefixes = [
      'Ondes',
      'Dans le sillage de',
      'Univers',
      'Écho',
      'Rotation',
    ];

    final List<Future<Map<String, dynamic>?>> slotFutures = List.generate(5, (idx) async {
      final int accentInt = accentColors[idx % accentColors.length];
      final String? artistAnchor = idx < cleanArtists.length ? cleanArtists[idx] : null;
      final theme = dynamicThemes[idx % dynamicThemes.length];

      final String playlistTitle = artistAnchor != null
          ? '${personalPrefixes[idx]} • $artistAnchor'
          : theme['title']!;
      final String playlistSubtitle = artistAnchor != null
          ? '30 sons dans le même univers que $artistAnchor'
          : theme['subtitle']!;

      final List<TrackModel> collected = [];
      final Set<String> seenIds = {};
      final Set<String> seenTitleKeys = {};

      void addAllUnique(List<TrackModel> source) {
        final filtered = effectiveProfile.isColdStart
            ? source
            : RecommendationEngine.rankTracksForProfile(
                source,
                effectiveProfile,
                limit: 30,
                maxPerArtist: 4,
                strictGate: true,
              );
        for (final t in filtered) {
          if (t.title.isEmpty) continue;
          final tKey = '${t.title.toLowerCase()}__${t.artistName.toLowerCase()}';
          if (seenIds.add(t.id) && seenTitleKeys.add(tKey)) {
            collected.add(t);
          }
        }
      }

      if (artistAnchor != null) {
        final primaryResults = await Future.wait([
          getSimilarTracks(artistAnchor, limit: 25),
          searchTracks(query: artistAnchor, limit: 15),
        ]);
        addAllUnique(primaryResults[0]);
        addAllUnique(primaryResults[1]);
        if (collected.length < 24) {
          final anchorFamily = RecommendationEngine.classifyArtist(artistAnchor);
          final familySeed = anchorFamily != null ? _familySearchSeed(anchorFamily) : null;
          final extraQuery = familySeed ?? '$artistAnchor mix';
          final extra = await searchTracks(query: extraQuery, limit: 25);
          addAllUnique(extra);
        }
      }

      if (collected.length < 24) {
        final themeQuery = theme['query']!;
        final fallback = await _getTracksFromPlaylistSearch(themeQuery, limit: 30);
        addAllUnique(fallback);
        if (collected.length < 20) {
          final more = await searchTracks(query: themeQuery, limit: 30);
          addAllUnique(more);
        }
      }

      if (collected.isEmpty) return null;

      final finalTracks = collected.take(30).toList();
      final List<String> covers = [];
      for (final t in finalTracks) {
        if (t.coverUrl.isNotEmpty && !covers.contains(t.coverUrl)) {
          covers.add(t.coverUrl);
          if (covers.length >= 4) break;
        }
      }

      return <String, dynamic>{
        'id': 'weekly_mix_${idx + 1}',
        'title': playlistTitle,
        'subtitle': playlistSubtitle,
        'accent': accentInt,
        'cover': covers.isNotEmpty ? covers.first : '',
        'covers': covers,
        'tracks': finalTracks.map((t) => t.toJson()).toList(),
      };
    });

    final resolved = await Future.wait(slotFutures);
    return resolved.whereType<Map<String, dynamic>>().toList();
  }

  List<Map<String, String>> _buildCuratedThemesForProfile(UserTasteProfile profile) {
    if (profile.isColdStart) {
      return const [
        {
          'title': 'Sélection Essentielle',
          'subtitle': '30 classiques intemporels & succès actuels',
          'query': 'Timeless Hits Classics Essentials',
        },
        {
          'title': 'Acoustique & Sérénité',
          'subtitle': '30 titres doux pour commencer votre écoute',
          'query': 'Chill Acoustic Vibe Relax',
        },
        {
          'title': 'Chanson, Jazz & Soul',
          'subtitle': '30 mélodies chaleureuses et élégantes',
          'query': 'Jazz Soul Chanson Classics',
        },
        {
          'title': 'Énergie & Rythme',
          'subtitle': '30 sons dynamiques sélectionnés pour vous',
          'query': 'Feel Good Pop Energy Hits',
        },
        {
          'title': 'Découvertes Sonoritiz',
          'subtitle': '30 pépites sélectionnées autour du monde',
          'query': 'Global Music Gems Curated',
        },
      ];
    }

    const Map<TasteFamily, List<Map<String, String>>> familyThemes = {
      TasteFamily.classical: [
        {
          'title': 'Classique & Grands Maîtres',
          'subtitle': '30 œuvres symphoniques et piano solo',
          'query': 'Classical Piano Symphony Masterpieces',
        },
        {
          'title': 'Néo-Classique & Musiques de Film',
          'subtitle': '30 compositions instrumentales immersives',
          'query': 'Ludovico Einaudi Max Richter Hans Zimmer',
        },
      ],
      TasteFamily.chanson: [
        {
          'title': 'Grands Classiques de la Chanson',
          'subtitle': '30 chefs-d’œuvre intemporels en français',
          'query': 'Charles Aznavour Edith Piaf Jacques Brel',
        },
        {
          'title': 'Variété & Poésie Acoustique',
          'subtitle': '30 belles voix francophones pour prolonger l’écoute',
          'query': 'Chanson Francaise Classique Gold',
        },
      ],
      TasteFamily.jazzSoul: [
        {
          'title': 'Jazz, Swing & Velours',
          'subtitle': '30 standards chaleureux inspirés de vos goûts',
          'query': 'Frank Sinatra Nina Simone Jazz Classics',
        },
        {
          'title': 'Soul Intemporelle',
          'subtitle': '30 classiques soul remplis d’émotion',
          'query': 'Stevie Wonder Marvin Gaye Soul Classics',
        },
      ],
      TasteFamily.popRock: [
        {
          'title': 'Pop & Rock Incontournables',
          'subtitle': '30 hymnes marquants dans votre univers',
          'query': 'Pop Rock Greatest Hits Essentials',
        },
      ],
      TasteFamily.rnb: [
        {
          'title': 'R&B & Sensations',
          'subtitle': '30 mélodies suaves inspirées de vos écoutes',
          'query': 'R&B Soul Essentials',
        },
      ],
      TasteFamily.hipHop: [
        {
          'title': 'Flow Rap & Lyrisme',
          'subtitle': '30 morceaux urbains adaptés à votre profil',
          'query': 'Hip Hop Rap Essentials',
        },
      ],
      TasteFamily.afro: [
        {
          'title': 'Vibe Afrobeats & Amapiano',
          'subtitle': '30 titres afro sélectionnés selon vos écoutes',
          'query': 'Afrobeats Amapiano Hits',
        },
      ],
      TasteFamily.electro: [
        {
          'title': 'Électro Mélodique & Nuit',
          'subtitle': '30 sons électroniques taillés sur mesure',
          'query': 'Melodic Electronic Chill House',
        },
      ],
      TasteFamily.latinWorld: [
        {
          'title': 'Soleil & Musiques du Monde',
          'subtitle': '30 rythmes chaleureux et acoustiques',
          'query': 'Bossa Nova Latin Acoustic Classics',
        },
      ],
    };

    final List<Map<String, String>> result = [];
    for (final family in profile.dominantFamilies) {
      final list = familyThemes[family];
      if (list != null) {
        result.addAll(list);
      }
    }
    if (result.isEmpty) {
      result.add(const {
        'title': 'Sélection Sur-Mesure',
        'subtitle': '30 titres proches de vos artistes préférés',
        'query': 'Timeless Music Essentials',
      });
    }
    return result;
  }

  /// 4.4 Rubrique Sonoritiz Random : Sélection de sons aléatoires pour sortir de la routine
  Future<List<TrackModel>> getSonoritizRandomTracks({
    int limit = 25,
    List<String> userArtists = const [],
    List<String> userKeywords = const [],
    UserTasteProfile? tasteProfile,
  }) async {
    final effectiveProfile = tasteProfile ??
        RecommendationEngine.buildProfile(
          selectedArtists: userArtists,
          superlikedTracks: const [],
          favoriteTracks: const [],
          favoriteAlbumArtists: const [],
          recentLocalEntries: const [],
          historyTracks: const [],
          searchedArtists: const [],
        );

    const Map<TasteFamily, List<String>> serendipityPools = {
      TasteFamily.jazzSoul: [
        'Nina Simone Ray Charles Jazz Soul Classics',
        'Neo Soul Erykah Badu Leon Bridges Vibes',
        'Smooth Jazz Lounge Saxophone Night',
      ],
      TasteFamily.classical: [
        'Ludovico Einaudi Max Richter Neo Classical Piano',
        'Chopin Debussy Clair De Lune Piano',
        'Hans Zimmer Ennio Morricone Soundtrack Masterpieces',
      ],
      TasteFamily.latinWorld: [
        'Stan Getz Joao Gilberto Bossa Nova Classics',
        'Buena Vista Social Club Cuban Acoustic',
        'Flamenco Guitar Mediterranean Acoustic Gems',
      ],
      TasteFamily.popRock: [
        'Fleetwood Mac Queen Indie Rock Classics',
        'Tame Impala Arctic Monkeys Alternative Pop',
        'Coldplay Oasis Acoustic Rock Anthems',
      ],
      TasteFamily.electro: [
        'Daft Punk Air French Touch Electronic',
        'Rufus Du Sol Ben Bohmer Melodic House',
        'Bonobo Tycho Chill Electronic Downtempo',
      ],
      TasteFamily.chanson: [
        'Charles Aznavour Jacques Brel Chanson Francaise',
        'Pomme Clara Luciani Stromae Indie Francophone',
        'Francis Cabrel Jean Jacques Goldman Acoustique',
      ],
      TasteFamily.rnb: [
        'SadeAlicia Keys Marvin Gaye Soul R&B',
        'Frank Ocean Daniel Caesar H.E.R. R&B',
        'Stevie Wonder Bill Withers Golden Soul',
      ],
      TasteFamily.afro: [
        'Fela Kuti Manu Dibango Afrobeat Legends',
        'Tems Burna Boy Wizkid Afro Soul Chill',
        'Cesaria Evora Youssou Ndour World Music Gems',
      ],
      TasteFamily.hipHop: [
        'A Tribe Called Quest Nujabes Jazz Hop Chill',
        'MC Solaar IAM Oxmo Puccino Rap Classique',
        'Kendrick Lamar J Cole Lauryn Hill Hip Hop Soul',
      ],
    };

    final rng = math.Random();
    final routineFamilies = effectiveProfile.dominantFamilies.take(2).toSet();

    // Prioriser les familles musicales EN DEHORS de la routine quotidienne de l'utilisateur
    final antiRoutineFamilies = TasteFamily.values
        .where((f) => !routineFamilies.contains(f))
        .toList()
      ..shuffle(rng);

    final selectedFamilies = <TasteFamily>[
      ...antiRoutineFamilies.take(4),
      if (antiRoutineFamilies.length > 4) antiRoutineFamilies[4],
    ];

    final List<String> discoveryQueries = [];
    for (final family in selectedFamilies) {
      final pool = serendipityPools[family];
      if (pool != null && pool.isNotEmpty) {
        discoveryQueries.add(pool[rng.nextInt(pool.length)]);
      }
    }

    if (discoveryQueries.isEmpty) {
      discoveryQueries.addAll(const [
        'Bossa Nova Jazz Classics',
        'Ludovico Einaudi Neo Classical Piano',
        'Fleetwood Mac Indie Rock Classics',
        'Daft Punk French Touch Electronic',
      ]);
    }

    // Exclure tous les artistes déjà présents dans la routine de l'utilisateur
    final Set<String> excludedArtists = {
      ...userArtists.map((a) => a.trim().toLowerCase()).where((a) => a.isNotEmpty),
      ...effectiveProfile.artistWeights.keys
          .map((a) => a.trim().toLowerCase())
          .where((a) => a.isNotEmpty),
    };

    final Set<String> excludedTrackIds = {
      ...effectiveProfile.preferredTrackIds,
      ...effectiveProfile.dislikedOrFilteredIds,
    };

    final batches = await Future.wait(
      discoveryQueries.take(5).map((q) => searchTracks(query: q, limit: 12)),
    );

    // Mélange interne de chaque lot pour varier l'ordre à chaque session
    final List<List<TrackModel>> shuffledBatches = batches.map((b) {
      final copy = List<TrackModel>.from(b)..shuffle(rng);
      return copy;
    }).toList();

    // Entrelacement (Round-Robin) entre les styles opposés avec 1 seul son max par artiste
    final List<TrackModel> selected = [];
    final Set<String> seenArtists = {};
    final Set<String> seenTrackIds = {};

    int maxBatchLen = 0;
    for (final b in shuffledBatches) {
      if (b.length > maxBatchLen) maxBatchLen = b.length;
    }

    for (int i = 0; i < maxBatchLen && selected.length < limit; i++) {
      for (final batch in shuffledBatches) {
        if (i >= batch.length || selected.length >= limit) continue;
        final t = batch[i];
        if (t.id.isEmpty ||
            seenTrackIds.contains(t.id) ||
            excludedTrackIds.contains(t.id)) {
          continue;
        }
        final titleLower = t.title.toLowerCase();
        if (titleLower.contains('karaoke') ||
            titleLower.contains('tribute') ||
            titleLower.contains('ringtone')) {
          continue;
        }
        final artistLower = t.artistName.trim().toLowerCase();
        if (artistLower.isEmpty || seenArtists.contains(artistLower)) {
          continue;
        }
        final isRoutineArtist = excludedArtists.any(
          (ex) => artistLower == ex || artistLower.contains(ex),
        );
        if (isRoutineArtist) continue;

        seenTrackIds.add(t.id);
        seenArtists.add(artistLower);
        selected.add(t);
      }
    }

    return selected;
  }
}
