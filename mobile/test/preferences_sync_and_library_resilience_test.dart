import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonoritiz/core/constants/api_constants.dart';
import 'package:sonoritiz/core/network/api_client.dart';
import 'package:sonoritiz/core/services/favorite_artists_sync_service.dart';
import 'package:sonoritiz/core/storage/storage_service.dart';
import 'package:sonoritiz/features/library/data/repositories/library_repository.dart';
import 'package:sonoritiz/features/library/presentation/cubit/library_cubit.dart';
import 'package:sonoritiz/features/library/presentation/cubit/library_state.dart';
import 'package:sonoritiz/features/player/data/models/track_model.dart';
import 'package:sonoritiz/features/player/presentation/cubit/superlike_cubit.dart';

class _RecordingApiClient extends ApiClient {
  final List<Map<String, dynamic>> patchCalls = [];
  final List<String> getCalls = [];
  Map<String, dynamic> preferencesResponse = const {
    'favorite_artists': <String>[],
    'superliked_tracks': <Map<String, dynamic>>[],
    'favorite_albums': <Map<String, dynamic>>[],
  };

  _RecordingApiClient() : super(storageService: StorageService());

  @override
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    getCalls.add(path);
    if (path == ApiConstants.userPreferences || path == ApiConstants.profile) {
      return Response(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: preferencesResponse,
      );
    }
    throw Exception('Unexpected GET $path');
  }

  @override
  Future<Response> patch(String path, {dynamic data}) async {
    patchCalls.add({
      'path': path,
      'data': data is Map ? Map<String, dynamic>.from(data) : data,
    });
    return Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: data,
    );
  }
}

class _StubLibraryRepository extends LibraryRepository {
  Future<List<TrackModel>> Function()? onGetFavorites;
  Future<List<PlaylistModel>> Function()? onGetPlaylists;
  Future<List<HistoryModel>> Function()? onGetHistory;

  _StubLibraryRepository() : super(apiClient: _RecordingApiClient());

  @override
  Future<List<TrackModel>> getFavorites() =>
      onGetFavorites?.call() ?? Future.value(const []);

  @override
  Future<List<PlaylistModel>> getPlaylists() =>
      onGetPlaylists?.call() ?? Future.value(const []);

  @override
  Future<List<HistoryModel>> getHistory() =>
      onGetHistory?.call() ?? Future.value(const []);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final Map<String, String> secureStore = {};

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sonoritiz_sync_unit_');
    Hive.init(tempDir.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments is Map) ? call.arguments as Map : const {};
        final key = args['key']?.toString();
        if (call.method == 'write' && key != null) {
          secureStore[key] = args['value']?.toString() ?? '';
          return null;
        }
        if (call.method == 'read' && key != null) {
          return secureStore[key];
        }
        if (call.method == 'delete' && key != null) {
          secureStore.remove(key);
          return null;
        }
        return null;
      },
    );
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() {
    secureStore.clear();
    StorageService.onFavoriteArtistsSaved = null;
    StorageService.onSuperlikesSaved = null;
    StorageService.onFavoriteAlbumsSaved = null;
  });

  group('Legacy global key migration', () {
    test('migrates legacy superlikes, favorite albums, lifetime plays, weekly playlists, and bio into account scope', () async {
      secureStore['access_token'] = 'legacy_tok';
      secureStore['refresh_token'] = 'legacy_ref';

      final legacySuperlikes = jsonEncode([
        {'id': 'yt_sl_1', 'title': 'Melo', 'artist_name': 'Tiakola', 'duration_seconds': 180, 'audio_url': ''}
      ]);
      final legacyAlbums = jsonEncode([
        {'id': 'alb_99', 'title': 'BDLM', 'artist_name': 'Tiakola'}
      ]);
      final legacyPlays = jsonEncode({
        'melo__tiakola': {'count': 4, 'last_played_at': '2026-11-10T10:00:00Z'}
      });
      final legacyWeekly = jsonEncode([
        {'id': 'w1', 'name': 'Mix 1', 'tracks': []}
      ]);

      SharedPreferences.setMockInitialValues({
        'username': 'ydedn',
        'email': 'samuelydedn@gmail.com',
        'favorite_artists': ['Tiakola', 'SDM'],
        'sonoritiz_superlikes': legacySuperlikes,
        'sonoritiz_favorite_albums': legacyAlbums,
        'lifetime_plays': legacyPlays,
        'weekly_curated_playlists_v3': legacyWeekly,
        'weekly_curated_playlists_ts_v3': 1700000000000,
        'user_bio': 'Sonoritiz Fan',
      });

      final storage = StorageService();
      await storage.init();

      expect(storage.getFavoriteArtists(), ['Tiakola', 'SDM']);
      expect(storage.getSuperlikesRaw().length, 1);
      expect(storage.getSuperlikesRaw().first['id'], 'yt_sl_1');
      expect(storage.getFavoriteAlbumsRaw().length, 1);
      expect(storage.getFavoriteAlbumsRaw().first['title'], 'BDLM');
      expect(storage.getLifetimeTrackPlaysRaw().containsKey('melo__tiakola'), isTrue);
      expect(storage.getWeeklyPlaylists()?.length, 1);
      expect(storage.getWeeklyPlaylistsTimestamp()?.millisecondsSinceEpoch, 1700000000000);
      expect(storage.userBio, 'Sonoritiz Fan');

      // Switching to another account does NOT see migrated data because global keys were cleared
      await storage.clearSession();
      await storage.saveTokens(accessToken: 'other_tok', refreshToken: 'other_ref');
      await storage.saveUserInfo(
        username: 'other',
        email: 'other@sonoritiz.com',
        isNewAccount: true,
      );
      expect(storage.getSuperlikesRaw(), isEmpty);
      expect(storage.getFavoriteAlbumsRaw(), isEmpty);
      expect(storage.getLifetimeTrackPlaysRaw(), isEmpty);
    });
  });

  group('Preferences sync for artists, superlikes, and favorite albums', () {
    test('restores server preferences on fresh login without redundant PATCH', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      await storage.saveTokens(accessToken: 'tok_u2', refreshToken: 'ref_u2');
      await storage.saveUserInfo(
        username: 'ydedn',
        email: 'samuelydedn@gmail.com',
      );

      final api = _RecordingApiClient();
      final sync = FavoriteArtistsSyncService(storageService: storage, apiClient: api);

      final artists = await sync.syncAfterAuth(
        serverArtists: ['Tiakola', 'SDM'],
        serverSuperlikes: [
          {'id': 'yt_1', 'title': 'Gasolina', 'artist_name': 'Tiakola', 'duration_seconds': 200, 'audio_url': ''},
        ],
        serverFavoriteAlbums: [
          {'id': 'alb_1', 'title': 'Mélo', 'artist_name': 'Tiakola'},
        ],
      );

      expect(artists, ['Tiakola', 'SDM']);
      expect(storage.getSuperlikesRaw().map((e) => e['id']).toList(), ['yt_1']);
      expect(storage.getFavoriteAlbumsRaw().map((e) => e['title']).toList(), ['Mélo']);
      expect(api.patchCalls, isEmpty);
      expect(api.getCalls, isEmpty);
    });

    test('pulls missing preference fields from /api/auth/preferences/ and merges local + remote', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      await storage.saveTokens(accessToken: 'tok_u2', refreshToken: 'ref_u2');
      await storage.saveUserInfo(
        username: 'ydedn',
        email: 'samuelydedn@gmail.com',
      );
      await storage.saveSuperlikesRaw([
        {'id': 'yt_local', 'title': 'Local Song', 'artist_name': 'Ninho', 'duration_seconds': 190, 'audio_url': ''},
      ], syncToServer: false);

      final api = _RecordingApiClient()
        ..preferencesResponse = {
          'favorite_artists': ['Tiakola'],
          'superliked_tracks': [
            {'id': 'yt_remote', 'title': 'Remote Song', 'artist_name': 'SDM', 'duration_seconds': 210, 'audio_url': ''},
          ],
          'favorite_albums': [
            {'id': 'alb_r1', 'title': 'Liens du 100', 'artist_name': 'SDM'},
          ],
        };
      final sync = FavoriteArtistsSyncService(storageService: storage, apiClient: api);

      await sync.syncAfterAuth(
        serverArtists: null,
        serverSuperlikes: null,
        serverFavoriteAlbums: null,
      );

      expect(api.getCalls, contains(ApiConstants.userPreferences));
      expect(storage.getSuperlikesRaw().map((e) => e['id']).toList(), ['yt_remote', 'yt_local']);
      expect(storage.getFavoriteAlbumsRaw().length, 1);
      // Merged superlikes now contain both remote + local, so it pushes back once
      expect(
        api.patchCalls.any((c) =>
            c['path'] == ApiConstants.userPreferences &&
            (c['data'] as Map).containsKey('superliked_tracks')),
        isTrue,
      );
    });

    test('SuperlikeCubit and LibraryCubit toggleFavoriteAlbum trigger sync hooks while cache loads do not', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      await storage.saveTokens(accessToken: 'tok_u3', refreshToken: 'ref_u3');
      await storage.saveUserInfo(username: 'u3', email: 'u3@sonoritiz.com');

      final api = _RecordingApiClient();
      final sync = FavoriteArtistsSyncService(storageService: storage, apiClient: api);
      StorageService.onSuperlikesSaved = sync.pushSuperlikes;
      StorageService.onFavoriteAlbumsSaved = sync.pushFavoriteAlbums;

      final superlikeCubit = SuperlikeCubit(storageService: storage);
      final added = await superlikeCubit.addSuperlike(const TrackModel(
        id: 'yt_s1',
        title: 'Sirop',
        artistName: 'Tiakola',
        durationSeconds: 180,
        audioUrl: 'https://example.com/s1.mp3',
      ));
      expect(added, isTrue);
      expect(
        api.patchCalls.where((c) => (c['data'] as Map).containsKey('superliked_tracks')).length,
        1,
      );
      await superlikeCubit.close();

      final repo = _StubLibraryRepository();
      final libraryCubit = LibraryCubit(
        repository: repo,
        cacheKeyProvider: () => 'test_lib_sync_${DateTime.now().microsecondsSinceEpoch}',
      );
      await libraryCubit.loadLibraryData(forceFresh: true);
      // Normal library load MUST NOT spam favorite_albums PATCH requests
      expect(
        api.patchCalls.where((c) => (c['data'] as Map).containsKey('favorite_albums')),
        isEmpty,
      );

      final liked = await libraryCubit.toggleFavoriteAlbum(
        albumId: '42',
        title: 'Mélo',
        artistName: 'Tiakola',
        coverUrl: 'https://example.com/melo.jpg',
        albumTracks: const [],
      );
      expect(liked, isTrue);
      expect(
        api.patchCalls.where((c) => (c['data'] as Map).containsKey('favorite_albums')).length,
        1,
      );
      await libraryCubit.close();
    });
  });

  group('LibraryCubit network resilience', () {
    test('emits LibraryError instead of empty LibraryLoaded when all endpoints fail without cache', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      await storage.saveTokens(accessToken: 'tok_net', refreshToken: 'ref_net');
      await storage.saveUserInfo(username: 'netuser', email: 'net@sonoritiz.com');

      final repo = _StubLibraryRepository()
        ..onGetFavorites = (() async => throw Exception('Timeout'))
        ..onGetPlaylists = (() async => throw Exception('Timeout'))
        ..onGetHistory = (() async => throw Exception('Timeout'));

      final cubit = LibraryCubit(
        repository: repo,
        cacheKeyProvider: () => 'test_lib_fail_${DateTime.now().microsecondsSinceEpoch}',
      );

      await cubit.loadLibraryData(forceFresh: true);
      expect(cubit.state, isA<LibraryError>());
      await cubit.close();
    });

    test('retries load immediately when previous load only partially succeeded', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      await storage.saveTokens(accessToken: 'tok_part', refreshToken: 'ref_part');
      await storage.saveUserInfo(username: 'partuser', email: 'part@sonoritiz.com');

      int playlistCalls = 0;
      final repo = _StubLibraryRepository()
        ..onGetFavorites = (() async => const [
              TrackModel(
                id: 'f1',
                title: 'Fav 1',
                artistName: 'Artist',
                durationSeconds: 180,
                audioUrl: '',
              ),
            ])
        ..onGetPlaylists = (() async {
          playlistCalls++;
          if (playlistCalls == 1) {
            throw Exception('Server timeout on playlists');
          }
          return [
            PlaylistModel(id: 7, name: 'Ma Playlist', tracksCount: 3),
          ];
        })
        ..onGetHistory = (() async => const []);

      final cubit = LibraryCubit(
        repository: repo,
        cacheKeyProvider: () => 'test_lib_partial_${DateTime.now().microsecondsSinceEpoch}',
      );

      await cubit.loadLibraryData(forceFresh: true);
      expect(cubit.state, isA<LibraryLoaded>());
      expect((cubit.state as LibraryLoaded).playlists, isEmpty);
      expect((cubit.state as LibraryLoaded).favorites.length, 1);

      // Second call without forceFresh should NOT be throttled because playlists failed on first attempt
      await cubit.loadLibraryData(forceFresh: false);
      expect(playlistCalls, 2);
      expect((cubit.state as LibraryLoaded).playlists.map((p) => p.name).toList(), ['Ma Playlist']);
      await cubit.close();
    });
  });
}
