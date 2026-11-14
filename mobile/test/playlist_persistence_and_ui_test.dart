import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonoritiz/core/constants/api_constants.dart';
import 'package:sonoritiz/core/network/api_client.dart';
import 'package:sonoritiz/core/storage/json_cache.dart';
import 'package:sonoritiz/core/storage/storage_service.dart';
import 'package:sonoritiz/core/widgets/playlist_cover_mosaic.dart';
import 'package:sonoritiz/features/library/data/repositories/library_repository.dart';
import 'package:sonoritiz/features/library/presentation/cubit/library_cubit.dart';
import 'package:sonoritiz/features/library/presentation/cubit/library_state.dart';
import 'package:sonoritiz/features/library/presentation/cubit/library_ui_cubit.dart';
import 'package:sonoritiz/features/library/presentation/playlists_list_screen.dart';
import 'package:sonoritiz/features/player/data/models/track_model.dart';

class _FakeApiClient extends ApiClient {
  final Map<String, Response Function(Map<String, dynamic>? query, dynamic data)> handlers = {};
  final List<Map<String, dynamic>> postedPlaylists = [];

  _FakeApiClient() : super(storageService: StorageService());

  @override
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    final handler = handlers['GET $path'];
    if (handler != null) {
      return handler(queryParameters, null);
    }
    throw Exception('Unexpected GET $path');
  }

  @override
  Future<Response> post(String path, {dynamic data}) async {
    if (path == ApiConstants.playlists && data is Map) {
      postedPlaylists.add(Map<String, dynamic>.from(data));
    }
    final handler = handlers['POST $path'];
    if (handler != null) {
      return handler(null, data);
    }
    throw Exception('Unexpected POST $path');
  }
}

class _StubLibraryRepository extends LibraryRepository {
  Future<List<TrackModel>> Function()? onGetFavorites;
  Future<List<PlaylistModel>> Function()? onGetPlaylists;
  Future<List<HistoryModel>> Function()? onGetHistory;
  Future<PlaylistModel> Function(String name, String coverUrl)? onCreatePlaylist;
  Future<void> Function(int playlistId, TrackModel track)? onAddTrack;
  Future<void> Function(int playlistId)? onDeletePlaylist;

  _StubLibraryRepository() : super(apiClient: _FakeApiClient());

  @override
  Future<List<TrackModel>> getFavorites() =>
      onGetFavorites?.call() ?? Future.value(const []);

  @override
  Future<List<PlaylistModel>> getPlaylists() =>
      onGetPlaylists?.call() ?? Future.value(const []);

  @override
  Future<List<HistoryModel>> getHistory() =>
      onGetHistory?.call() ?? Future.value(const []);

  @override
  Future<PlaylistModel> createPlaylist(String name, {String coverUrl = ''}) =>
      onCreatePlaylist?.call(name, coverUrl) ??
      Future.value(PlaylistModel(id: 100, name: name, coverUrl: coverUrl));

  @override
  Future<void> addTrackToPlaylist(int playlistId, TrackModel track) =>
      onAddTrack?.call(playlistId, track) ?? Future.value();

  @override
  Future<void> deletePlaylist(int playlistId) =>
      onDeletePlaylist?.call(playlistId) ?? Future.value();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sonoritiz_test_');
    Hive.init(tempDir.path);
    SharedPreferences.setMockInitialValues({
      'username': 'tester',
      'library_sort_mode_playlists': 'recent',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    await StorageService().init();
  });

  setUp(() async {
    await JsonCache.clearAll();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LibraryRepository playlist safeguards', () {
    test('getPlaylists fetches all pages using limit and offset pagination', () async {
      final api = _FakeApiClient();
      final page1 = List.generate(
        50,
        (i) => {'id': i + 1, 'name': 'PL ${i + 1}', 'tracks': [], 'tracks_count': 0},
      );
      final page2 = [
        {'id': 51, 'name': 'PL 51', 'tracks': [], 'tracks_count': 0},
      ];

      api.handlers['GET ${ApiConstants.playlists}?limit=50&offset=0'] = (_, __) => Response(
            requestOptions: RequestOptions(path: ApiConstants.playlists),
            statusCode: 200,
            data: {'count': 51, 'next': 'https://sonoritiz.vercel.app/api/playlists/?offset=50', 'results': page1},
          );
      api.handlers['GET ${ApiConstants.playlists}?limit=50&offset=50'] = (_, __) => Response(
            requestOptions: RequestOptions(path: ApiConstants.playlists),
            statusCode: 200,
            data: {'count': 51, 'next': null, 'results': page2},
          );

      final repo = LibraryRepository(apiClient: api);
      final playlists = await repo.getPlaylists();

      expect(playlists.length, 51);
      expect(playlists.last.name, 'PL 51');
    });

    test('createPlaylist strips oversized local cover_url above 500 chars', () async {
      final api = _FakeApiClient();
      final oversizedPath = '/storage/emulated/0/${'a' * 520}.jpg';
      api.handlers['POST ${ApiConstants.playlists}'] = (_, data) => Response(
            requestOptions: RequestOptions(path: ApiConstants.playlists),
            statusCode: 201,
            data: {'id': 77, 'name': data['name'], 'cover_url': data['cover_url'], 'tracks': [], 'tracks_count': 0},
          );

      final repo = LibraryRepository(apiClient: api);
      final created = await repo.createPlaylist('Roadtrip', coverUrl: 'file://$oversizedPath');

      expect(created.id, 77);
      expect(api.postedPlaylists.single['cover_url'], '');
    });
  });

  group('LibraryCubit playlist persistence and race protection', () {
    test('playlist created while loadLibraryData is in-flight is never overwritten', () async {
      final repo = _StubLibraryRepository();
      final playlistsCompleter = Completer<List<PlaylistModel>>();

      repo.onGetPlaylists = () => playlistsCompleter.future;
      repo.onCreatePlaylist = (name, coverUrl) async => PlaylistModel(
            id: 42,
            name: name,
            coverUrl: coverUrl,
          );

      final cubit = LibraryCubit(
        repository: repo,
        cacheKeyProvider: () => 'library_race_test',
      );

      final loadFuture = cubit.loadLibraryData();
      // Simule la création juste après le retour d'ImagePicker pendant que loadLibraryData attend le réseau
      await Future<void>.delayed(Duration.zero);
      final created = await cubit.createPlaylist('Ma Nouvelle Playlist');

      expect(created.id, 42);

      // Le vieux fetch distant se termine sans contenir la playlist fraîchement créée
      playlistsCompleter.complete([
        PlaylistModel(id: 1, name: 'Ancienne Playlist'),
      ]);
      await loadFuture;

      final loaded = cubit.state as LibraryLoaded;
      expect(loaded.playlists.any((p) => p.id == 42 && p.name == 'Ma Nouvelle Playlist'), isTrue);
      expect(loaded.playlists.any((p) => p.id == 1), isTrue);

      await cubit.close();
    });

    test('offline created playlist is kept, enriched with tracks, and synced when online later', () async {
      final repo = _StubLibraryRepository();
      var serverOnline = false;
      final addedOnServer = <String>[];

      repo.onGetPlaylists = () async {
        if (!serverOnline) throw Exception('Offline');
        return [PlaylistModel(id: 5, name: 'Existante')];
      };
      repo.onCreatePlaylist = (name, coverUrl) async {
        if (!serverOnline) throw Exception('Offline');
        return PlaylistModel(id: 88, name: name, coverUrl: coverUrl);
      };
      repo.onAddTrack = (playlistId, track) async {
        addedOnServer.add('$playlistId:${track.id}');
      };

      final cubit = LibraryCubit(
        repository: repo,
        cacheKeyProvider: () => 'library_offline_sync_test',
      );

      await cubit.loadLibraryData();

      final offlineCreated = await cubit.createPlaylist('Hors Ligne');
      expect(offlineCreated.id, lessThan(0));

      const track = TrackModel(
        id: 'yt_123',
        title: 'Solar',
        artistName: 'Sonoritiz',
        durationSeconds: 180,
        audioUrl: '',
      );
      await cubit.addTrackToPlaylist(offlineCreated.id, track);

      var loaded = cubit.state as LibraryLoaded;
      expect(loaded.playlists.first.tracks.length, 1);

      // Reconnexion : un nouveau chargement détecte la playlist id < 0 et la pousse au serveur
      serverOnline = true;
      await cubit.loadLibraryData();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      loaded = cubit.state as LibraryLoaded;
      expect(cubit.resolvePlaylistId(offlineCreated.id), 88);
      final synced = loaded.playlists.firstWhere((p) => p.id == 88);
      expect(synced.name, 'Hors Ligne');
      expect(synced.tracks.length, 1);
      expect(addedOnServer, contains('88:yt_123'));

      await cubit.close();
    });

    test('deleted playlist is not resurrected by an in-flight loadLibraryData', () async {
      final repo = _StubLibraryRepository();
      final playlistsCompleter = Completer<List<PlaylistModel>>();

      repo.onGetPlaylists = () async => [
            PlaylistModel(id: 10, name: 'À supprimer'),
            PlaylistModel(id: 11, name: 'À garder'),
          ];

      final cubit = LibraryCubit(
        repository: repo,
        cacheKeyProvider: () => 'library_delete_race_test',
      );

      await cubit.loadLibraryData();

      // Relance un fetch lent puis supprime entre-temps
      repo.onGetPlaylists = () => playlistsCompleter.future;
      // forceFresh bypass le cooldown de 5s pour simuler un refresh actif
      final refreshFuture = cubit.loadLibraryData(forceFresh: true);
      await Future<void>.delayed(Duration.zero);

      await cubit.deletePlaylist(10);

      playlistsCompleter.complete([
        PlaylistModel(id: 10, name: 'À supprimer'),
        PlaylistModel(id: 11, name: 'À garder'),
      ]);
      await refreshFuture;

      final loaded = cubit.state as LibraryLoaded;
      expect(loaded.playlists.any((p) => p.id == 10), isFalse);
      expect(loaded.playlists.any((p) => p.id == 11), isTrue);

      await cubit.close();
    });
  });

  group('Playlist UI widgets', () {
    testWidgets('PlaylistCoverMosaic keeps 3-cover triptych layout and falls back if local file missing', (tester) async {
      final playlist = PlaylistModel(
        id: 1,
        name: 'Triptyque',
        coverUrl: 'file:///non_existent_cover_path_12345.jpg',
        tracks: const [
          TrackModel(
            id: '1',
            title: 'A',
            artistName: 'Art1',
            coverUrl: 'https://example.com/1.jpg',
            durationSeconds: 120,
            audioUrl: '',
          ),
          TrackModel(
            id: '2',
            title: 'B',
            artistName: 'Art2',
            coverUrl: 'https://example.com/2.jpg',
            durationSeconds: 120,
            audioUrl: '',
          ),
          TrackModel(
            id: '3',
            title: 'C',
            artistName: 'Art3',
            coverUrl: 'https://example.com/3.jpg',
            durationSeconds: 120,
            audioUrl: '',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PlaylistCoverMosaic(
                playlist: playlist,
                size: 160,
                height: 170,
              ),
            ),
          ),
        ),
      );

      // Le triptyque 3 pochettes (Expanded 65% gauche + Expanded 35% colonne droite) doit s'afficher
      final expandeds = tester.widgetList<Expanded>(find.byType(Expanded)).toList();
      expect(expandeds.any((e) => e.flex == 65), isTrue);
      expect(expandeds.any((e) => e.flex == 35), isTrue);
    });

    testWidgets('PlaylistsListScreen recent sort places pending local playlist (id < 0) first', (tester) async {
      final repo = _StubLibraryRepository();
      final cubit = LibraryCubit(
        repository: repo,
        cacheKeyProvider: () => 'library_widget_sort_test',
      );
      final uiCubit = LibraryUiCubit(storageService: StorageService());

      final playlists = [
        PlaylistModel(id: 5, name: 'Serveur Récente'),
        PlaylistModel(id: 2, name: 'Serveur Ancienne'),
        PlaylistModel(id: -1731540000000, name: 'Nouvelle Locale'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider.value(value: uiCubit),
            ],
            child: PlaylistsListScreen(playlists: playlists),
          ),
        ),
      );
      await tester.pump();

      final newPos = tester.getTopLeft(find.text('Nouvelle Locale')).dy;
      final serverRecentPos = tester.getTopLeft(find.text('Serveur Récente')).dy;
      final serverOldPos = tester.getTopLeft(find.text('Serveur Ancienne')).dy;

      expect(newPos, lessThan(serverRecentPos));
      expect(serverRecentPos, lessThan(serverOldPos));

      await uiCubit.close();
      await cubit.close();
    });
  });
}
