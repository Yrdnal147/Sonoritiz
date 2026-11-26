import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/storage_service.dart' show StorageService;
import '../../../../core/storage/json_cache.dart';
import '../../../../core/constants/artists_data.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/recommendation_engine.dart';
import '../../../library/data/repositories/library_repository.dart';
import '../../../player/data/models/track_model.dart';
import '../../domain/new_release_notifier.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final CatalogRepository catalogRepository;
  final LibraryRepository libraryRepository;
  final StorageService storageService;

  HomeCubit({
    required this.catalogRepository,
    required this.libraryRepository,
    required this.storageService,
  }) : super(HomeInitial());

  bool _hydrating = false;
  Future<void>? _homeLoadInFlight;
  String _loadedAccountScope = '';
  Timer? _cacheSaveDebounce;

  String get _cacheKey => 'home_v4_${storageService.accountScope}';

  void resetSessionState() {
    _cacheSaveDebounce?.cancel();
    _homeLoadInFlight = null;
    _loadedAccountScope = '';
    emit(HomeInitial());
  }

  @override
  Future<void> close() {
    _cacheSaveDebounce?.cancel();
    return super.close();
  }

  @override
  void onChange(Change<HomeState> change) {
    super.onChange(change);
    final next = change.nextState;
    if (!_hydrating && next is HomeLoaded) {
      // Ignorer les états intermédiaires de chargement (changement d'ambiance ou de continent)
      if (next.isMoodLoading || next.isContinentLoading) return;
      _cacheSaveDebounce?.cancel();
      _cacheSaveDebounce = Timer(const Duration(milliseconds: 1500), () {
        if (!isClosed) {
          _saveCache(next);
        }
      });
    }
  }

  List<Map<String, dynamic>> _tracksToJson(List<TrackModel> tracks) =>
      tracks.map((t) => t.toJson()).toList();

  List<TrackModel> _tracksFromJson(dynamic raw) => (raw as List? ?? [])
      .map((e) => TrackModel.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  List<Map<String, String>> _stringMapsFromJson(dynamic raw) => (raw as List? ?? [])
      .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')))
      .toList();

  List<Map<String, dynamic>> _sanitizeWeeklyForJson(List<Map<String, dynamic>> playlists) {
    return playlists.map((p) {
      final copy = Map<String, dynamic>.from(p);
      final accent = copy['accent'];
      if (accent != null && accent is! int) {
        try {
          // ignore: avoid_dynamic_calls
          copy['accent'] = (accent as dynamic).value as int;
        } catch (_) {
          copy['accent'] = 0xFFFF6D00;
        }
      }
      return copy;
    }).toList();
  }

  Future<void> _saveCache(HomeLoaded s) async {
    try {
      await JsonCache.write(_cacheKey, {
        'greeting': s.contextualGreeting,
        'contextualTracks': _tracksToJson(s.contextualTracks),
        'dailyMixes': s.dailyMixes.map((k, v) => MapEntry(k, _tracksToJson(v))),
        'similarToArtistName': s.similarToArtistName,
        'similarToArtistTracks': _tracksToJson(s.similarToArtistTracks),
        'newReleases': _tracksToJson(s.newReleases),
        'trendingTracks': _tracksToJson(s.trendingTracks),
        'recentTrends': _tracksToJson(s.recentTrends),
        'recommendations': _tracksToJson(s.recommendations),
        'podcastTracks': _tracksToJson(s.podcastTracks),
        'topArtists': s.topArtists,
        'favoriteArtists': s.favoriteArtists,
        'userPlaylists': s.userPlaylists
            .map((p) => {
                  'id': p.id,
                  'name': p.name,
                  'cover_url': p.coverUrl,
                  'tracks_count': p.tracksCount,
                  'is_pinned': p.isPinned,
                  'tracks': p.tracks.map((t) => {'track_details': t.toJson()}).toList(),
                })
            .toList(),
        'userFavorites': _tracksToJson(s.userFavorites),
        'genres': s.genres,
        'editorialPlaylists': s.editorialPlaylists,
        'selectedMood': s.selectedMood,
        'moodTracks': _tracksToJson(s.moodTracks),
        'afrobeatsTracks': _tracksToJson(s.afrobeatsTracks),
        'cameroonTracks': _tracksToJson(s.cameroonTracks),
        'topUsaTracks': _tracksToJson(s.topUsaTracks),
        'hasAfroAffinity': s.hasAfroAffinity,
        'hasUsPopAffinity': s.hasUsPopAffinity,
        'continentalCharts': s.continentalCharts.map((k, v) => MapEntry(k, _tracksToJson(v))),
        'recentlyPlayed': _tracksToJson(s.recentlyPlayed),
        'weeklyCuratedPlaylists': _sanitizeWeeklyForJson(s.weeklyCuratedPlaylists),
        'sonoritizRandomTracks': _tracksToJson(s.sonoritizRandomTracks),
        'upcomingReleases': s.upcomingReleases,
      });
    } catch (_) {}
  }

  Future<HomeLoaded?> _readCache() async {
    try {
      final d = await JsonCache.read(_cacheKey);
      if (d is! Map) return null;
      final mixes = <String, List<TrackModel>>{};
      (d['dailyMixes'] as Map? ?? {}).forEach((k, v) => mixes[k.toString()] = _tracksFromJson(v));
      final editorialPlaylists = (d['editorialPlaylists'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final weeklyPlaylists = (d['weeklyCuratedPlaylists'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final upcomingReleases = (d['upcomingReleases'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final contCharts = <String, List<TrackModel>>{};
      (d['continentalCharts'] as Map? ?? {}).forEach((k, v) {
        contCharts[k.toString()] = _tracksFromJson(v);
      });
      final loaded = HomeLoaded(
        contextualGreeting: (d['greeting'] ?? 'Salut').toString(),
        contextualTracks: _tracksFromJson(d['contextualTracks']),
        dailyMixes: mixes,
        similarToArtistName: d['similarToArtistName'] as String?,
        similarToArtistTracks: _tracksFromJson(d['similarToArtistTracks']),
        newReleases: _tracksFromJson(d['newReleases']),
        trendingTracks: _tracksFromJson(d['trendingTracks']),
        recentTrends: _tracksFromJson(d['recentTrends']),
        recommendations: _tracksFromJson(d['recommendations']),
        podcastTracks: _tracksFromJson(d['podcastTracks']),
        topArtists: _stringMapsFromJson(d['topArtists']),
        favoriteArtists: _stringMapsFromJson(d['favoriteArtists']),
        userPlaylists: (d['userPlaylists'] as List? ?? [])
            .map((e) => PlaylistModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        userFavorites: _tracksFromJson(d['userFavorites']),
        genres: _stringMapsFromJson(d['genres']),
        editorialPlaylists: editorialPlaylists,
        selectedMood: (d['selectedMood'] ?? _getDefaultMoodForCurrentHour()).toString(),
        moodTracks: _tracksFromJson(d['moodTracks']),
        afrobeatsTracks: _tracksFromJson(d['afrobeatsTracks']),
        cameroonTracks: _tracksFromJson(d['cameroonTracks']),
        topUsaTracks: _tracksFromJson(d['topUsaTracks']),
        hasAfroAffinity: d['hasAfroAffinity'] is bool ? d['hasAfroAffinity'] as bool : true,
        hasUsPopAffinity: d['hasUsPopAffinity'] is bool ? d['hasUsPopAffinity'] as bool : true,
        continentalCharts: contCharts,
        recentlyPlayed: _tracksFromJson(d['recentlyPlayed']),
        weeklyCuratedPlaylists: weeklyPlaylists,
        sonoritizRandomTracks: _tracksFromJson(d['sonoritizRandomTracks']),
        upcomingReleases: upcomingReleases,
      );
      // Un cache vide n'a aucun intérêt : on préfère le squelette de chargement.
      if (loaded.trendingTracks.isEmpty &&
          loaded.contextualTracks.isEmpty &&
          loaded.newReleases.isEmpty &&
          loaded.recentlyPlayed.isEmpty &&
          loaded.weeklyCuratedPlaylists.isEmpty) {
        return null;
      }
      return loaded;
    } catch (_) {
      return null;
    }
  }

  /// Charge l'accueil sans jamais bloquer l'écran :
  /// - déjà des données affichées -> elles restent visibles, rafraîchissement silencieux ;
  /// - sinon, dernier contenu connu lu sur le disque -> affiché instantanément ;
  /// - le squelette n'apparaît qu'au tout premier lancement (aucune donnée connue).
  Future<void> loadHomeData({bool forceRefresh = false}) {
    if (!forceRefresh) {
      final currentLoad = _homeLoadInFlight;
      if (currentLoad != null) return currentLoad;
    }

    final load = _loadHomeData(forceRefresh: forceRefresh);
    _homeLoadInFlight = load;
    return load.whenComplete(() {
      if (identical(_homeLoadInFlight, load)) _homeLoadInFlight = null;
    });
  }

  String _getDefaultMoodForCurrentHour() {
    final now = DateTime.now();
    final hour = now.hour;
    final isWeekendNight = now.weekday == DateTime.friday || now.weekday == DateTime.saturday;
    if (hour >= 5 && hour < 9) return 'trajet';
    if (hour >= 9 && hour < 16) return 'focus';
    if (hour >= 16 && hour < 19) return 'sport';
    if (hour >= 19 && hour < 23) return isWeekendNight ? 'soiree' : 'detente';
    return 'nocturne';
  }

  /// Construit le profil de goût musical strictement isolé pour le compte actif.
  UserTasteProfile buildUserTasteProfile({
    List<TrackModel>? overrideFavorites,
    List<TrackModel>? overrideHistory,
  }) {
    final currentLoaded = state is HomeLoaded ? state as HomeLoaded : null;
    final selectedArtists = storageService.getFavoriteArtists();
    final superlikes = storageService
        .getSuperlikesRaw()
        .map((j) => TrackModel.fromJson(j))
        .where((t) => t.id.trim().isNotEmpty)
        .toList();
    final favoriteTracks = overrideFavorites ?? currentLoaded?.userFavorites ?? const <TrackModel>[];
    final favoriteAlbumArtists = storageService
        .getFavoriteAlbumsRaw()
        .map((a) => (a['artistName'] ?? a['artist'] ?? '').toString())
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final recentEntries = storageService.getRecentLocalTrackEntries(withinDays: 14);
    final historyTracks = overrideHistory ?? const <TrackModel>[];
    final searchedArtists = storageService
        .getUserSearchedArtistsRaw()
        .map((a) => (a['name'] ?? '').toString())
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return RecommendationEngine.buildProfile(
      selectedArtists: selectedArtists,
      superlikedTracks: superlikes,
      favoriteTracks: favoriteTracks,
      favoriteAlbumArtists: favoriteAlbumArtists,
      recentLocalEntries: recentEntries,
      historyTracks: historyTracks,
      searchedArtists: searchedArtists,
    );
  }

  Future<void> _loadHomeData({bool forceRefresh = false}) async {
    final currentScope = storageService.accountScope;
    final bool scopeChanged =
        _loadedAccountScope.isNotEmpty && _loadedAccountScope != currentScope;
    _loadedAccountScope = currentScope;

    if (forceRefresh || scopeChanged || state is! HomeLoaded) {
      final cached = await _readCache();
      if (isClosed) return;
      if (cached != null) {
        _hydrating = true;
        emit(cached);
        _hydrating = false;
      } else {
        emit(HomeLoading());
      }
    }
    try {
      // Salutation sobre et élégante
      const String greeting = "Salut";
      final defaultMood = _getDefaultMoodForCurrentHour();

      // 1. Extraction immédiate de l'historique local horodaté du compte actif (0 ms réseau)
      final existingState =
          (!forceRefresh && !scopeChanged && state is HomeLoaded)
              ? state as HomeLoaded
              : null;
      final allLocalEntries = storageService.getRecentLocalTrackEntries();
      final recent7dEntries = storageService.getRecentLocalTrackEntries(withinDays: 7);
      final localRecentTracks = _parseLocalRecentTracks(allLocalEntries, limit: 30);

      final favoriteArtistNames = storageService.getFavoriteArtists();
      final catalogArtists = ArtistsData.getArtistsForCategory('Tous');
      final favoriteArtists = favoriteArtistNames.map((name) {
        return catalogArtists.firstWhere(
          (a) => (a['name'] ?? '').toLowerCase() == name.toLowerCase(),
          orElse: () => {'name': name, 'imageUrl': ''},
        );
      }).toList();

      // 2. Phase rapide : requêtes d'accueil essentielles (en parallèle)
      final results = await Future.wait([
        catalogRepository.getTrendingTracks(limit: 50).catchError((_) => <TrackModel>[]),
        catalogRepository.getRecentTrends(limit: 25).catchError((_) => <TrackModel>[]),
        libraryRepository.getFavorites().catchError((_) => <TrackModel>[]),
        libraryRepository.getPlaylists().catchError((_) => <PlaylistModel>[]),
        catalogRepository.getNewReleasesOfTheWeek(limit: 20).catchError((_) => <TrackModel>[]),
        catalogRepository.getUpcomingAndNewReleases(limit: 15).catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (isClosed) return;

      final trendingTracks = results[0] as List<TrackModel>;
      final recentTrends = results[1] as List<TrackModel>;
      final userFavorites = results[2] as List<TrackModel>;
      final userPlaylists = results[3] as List<PlaylistModel>;
      final newReleases = results[4] as List<TrackModel>;
      final upcomingReleases = results[5] as List<Map<String, dynamic>>;

      // 3. Vérifier validité du cache 7 jours (5 séries complètes)
      final cachedWeekly = storageService.getWeeklyPlaylists();
      final weeklyTs = storageService.getWeeklyPlaylistsTimestamp();
      final now = DateTime.now();
      final isWeeklyValid = cachedWeekly != null &&
          cachedWeekly.length >= 5 &&
          cachedWeekly.every((p) => (p['tracks'] as List? ?? []).length >= 10) &&
          weeklyTs != null &&
          now.difference(weeklyTs).inDays < 7;

      final initialWeekly = (cachedWeekly != null && cachedWeekly.isNotEmpty)
          ? cachedWeekly
          : (existingState?.weeklyCuratedPlaylists ?? const <Map<String, dynamic>>[]);
      final initialRecentlyPlayed = localRecentTracks.isNotEmpty
          ? localRecentTracks
          : (existingState?.recentlyPlayed ?? const <TrackModel>[]);

      // Hors-ligne / API indisponible : on garde le contenu déjà affiché.
      final fetchedNothing = trendingTracks.isEmpty &&
          recentTrends.isEmpty &&
          newReleases.isEmpty &&
          upcomingReleases.isEmpty;
      if (fetchedNothing &&
          initialRecentlyPlayed.isEmpty &&
          initialWeekly.isEmpty &&
          state is HomeLoaded) {
        return;
      }

      // Lancer la vérification des nouveautés (Notification en tâche de fond sécurisée)
      try {
        NewReleaseNotifier(libraryRepository, catalogRepository)
            .checkAndNotifyNewReleases(newReleases)
            .catchError((e) {
          debugPrint('NewReleaseNotifier check error: $e');
        });
      } catch (e) {
        debugPrint('NewReleaseNotifier sync error: $e');
      }

      // ── ÉMETTRE IMMÉDIATEMENT avec les données rapides + locales ──
      final trendingIds = trendingTracks.map((t) => t.id).toSet();
      final distinctDiscoveries = recentTrends
          .where((t) => !trendingIds.contains(t.id))
          .toList();
      final discoverySource =
          distinctDiscoveries.isNotEmpty ? distinctDiscoveries : recentTrends;

      final initialProfile = buildUserTasteProfile(
        overrideFavorites: userFavorites,
      );
      final List<TrackModel> filteredTrending = initialProfile.isColdStart
          ? trendingTracks
          : RecommendationEngine.rankTracksForProfile(
              [...trendingTracks, ...recentTrends],
              initialProfile,
              limit: 25,
              maxPerArtist: 2,
              strictGate: true,
            );
      final List<TrackModel> displayTrending =
          filteredTrending.isNotEmpty ? filteredTrending : trendingTracks;

      final Map<String, List<TrackModel>> fallbackMixes = {};
      if (initialProfile.isColdStart) {
        if (trendingTracks.isNotEmpty) {
          fallbackMixes["Mix Populaire"] = trendingTracks.take(10).toList();
        }
        if (discoverySource.isNotEmpty) {
          fallbackMixes["Mix Découvertes"] = discoverySource.take(10).toList();
        }
      }

      emit(HomeLoaded(
        contextualGreeting: greeting,
        contextualTracks: existingState?.contextualTracks ?? const [],
        dailyMixes: fallbackMixes.isNotEmpty
            ? fallbackMixes
            : (existingState?.dailyMixes ?? const {}),
        similarToArtistName: existingState?.similarToArtistName,
        similarToArtistTracks: existingState?.similarToArtistTracks ?? const [],
        newReleases: newReleases.isNotEmpty
            ? newReleases
            : (existingState?.newReleases ?? const []),
        trendingTracks: displayTrending.isNotEmpty
            ? displayTrending
            : (existingState?.trendingTracks ?? const []),
        recentTrends: discoverySource.isNotEmpty
            ? discoverySource
            : (existingState?.recentTrends ?? const []),
        recommendations: existingState?.recommendations ?? const [],
        podcastTracks: existingState?.podcastTracks ?? const [],
        topArtists: existingState?.topArtists ?? const [],
        favoriteArtists: favoriteArtists,
        userPlaylists: userPlaylists,
        userFavorites: userFavorites,
        genres: existingState?.genres ?? const [],
        editorialPlaylists: existingState?.editorialPlaylists ?? const [],
        selectedMood: defaultMood,
        moodTracks: existingState?.moodTracks ?? const [],
        afrobeatsTracks: initialProfile.hasAfroAffinity
            ? (existingState?.afrobeatsTracks ?? const [])
            : const [],
        cameroonTracks: initialProfile.hasAfroAffinity
            ? (existingState?.cameroonTracks ?? const [])
            : const [],
        topUsaTracks: initialProfile.hasUsPopHipHopAffinity
            ? (existingState?.topUsaTracks ?? const [])
            : const [],
        continentalCharts: existingState?.continentalCharts ?? const {},
        recentlyPlayed: initialRecentlyPlayed,
        weeklyCuratedPlaylists: initialWeekly,
        sonoritizRandomTracks: existingState?.sonoritizRandomTracks ?? const [],
        hasAfroAffinity: initialProfile.hasAfroAffinity,
        hasUsPopAffinity: initialProfile.hasUsPopHipHopAffinity,
        upcomingReleases: upcomingReleases.isNotEmpty
            ? upcomingReleases
            : (existingState?.upcomingReleases ?? const []),
      ));

      // 4. Phase personnalisation 7 jours, Sonoritiz Random & Historique serveur (isolée)
      final profile = _extract7DayProfile(
        recent7dEntries,
        localRecentTracks,
        favoriteArtistNames,
      );
      var profileArtists = profile['artists']!;
      var profileKeywords = profile['keywords']!;

      List<HistoryModel> prefetchedHistory = const [];
      if (profileArtists.isEmpty) {
        try {
          prefetchedHistory =
              await libraryRepository.getHistory().catchError((_) => <HistoryModel>[]);
        } catch (_) {}
        if (prefetchedHistory.isNotEmpty) {
          final serverTracks = prefetchedHistory
              .where((h) => h.track != null)
              .map((h) => h.track!)
              .toList();
          final serverProfile =
              _extract7DayProfile(const [], serverTracks, favoriteArtistNames);
          profileArtists = serverProfile['artists']!;
          profileKeywords = serverProfile['keywords']!;
        }
      }

      final Future<List<HistoryModel>> historyFuture =
          (prefetchedHistory.isNotEmpty || profileArtists.isEmpty)
              ? Future.value(prefetchedHistory)
              : libraryRepository.getHistory().catchError((_) => <HistoryModel>[]);

      final initialTasteProfile = buildUserTasteProfile();

      final Future<List<Map<String, dynamic>>> weeklyFuture = isWeeklyValid
          ? Future.value(cachedWeekly)
          : () async {
              try {
                final generated = await catalogRepository.generateWeeklyCuratedPlaylists(
                  topArtists: profileArtists,
                  topKeywords: profileKeywords,
                  tasteProfile: initialTasteProfile,
                );
                if (generated.isNotEmpty) {
                  await storageService.saveWeeklyPlaylists(generated);
                  return generated;
                }
              } catch (e) {
                debugPrint('Weekly curated generation error: $e');
              }
              return initialWeekly;
            }();

      final Future<List<TrackModel>> randomFuture = () async {
        try {
          return await catalogRepository.getSonoritizRandomTracks(
            limit: 25,
            userArtists: profileArtists,
            userKeywords: profileKeywords,
            tasteProfile: initialTasteProfile,
          );
        } catch (e) {
          debugPrint('Sonoritiz random error: $e');
          return <TrackModel>[];
        }
      }();

      final discoveryResults = await Future.wait([
        historyFuture,
        weeklyFuture,
        randomFuture,
      ]);
      if (isClosed) return;

      final fetchedHistory = discoveryResults[0] as List<HistoryModel>;
      final weeklyCuratedPlaylists = discoveryResults[1] as List<Map<String, dynamic>>;
      final sonoritizRandomTracks = discoveryResults[2] as List<TrackModel>;

      final serverRecentTracks = fetchedHistory
          .where((h) => h.track != null)
          .map((h) => h.track!)
          .toList();
      final mergedRecentlyPlayed =
          _mergeRecentTracks(localRecentTracks, serverRecentTracks, limit: 30);

      if (state is HomeLoaded) {
        final cur = state as HomeLoaded;
        emit(cur.copyWith(
          recentlyPlayed:
              mergedRecentlyPlayed.isNotEmpty ? mergedRecentlyPlayed : cur.recentlyPlayed,
          weeklyCuratedPlaylists: weeklyCuratedPlaylists.isNotEmpty
              ? weeklyCuratedPlaylists
              : cur.weeklyCuratedPlaylists,
          sonoritizRandomTracks: sonoritizRandomTracks.isNotEmpty
              ? sonoritizRandomTracks
              : cur.sonoritizRandomTracks,
        ));
      }

      // 5. Charger les rubriques éditoriales, tops régionaux & continentaux en arrière-plan
      _loadSecondaryData(
        favoriteArtistNames: favoriteArtistNames.isNotEmpty
            ? favoriteArtistNames
            : profileArtists.take(5).toList(),
        trendingTracks: trendingTracks,
        recentTrends: discoverySource,
        defaultMood: defaultMood,
      );
    } catch (e, stack) {
      if (isClosed) return;
      debugPrint('=== ERREUR HOME CUBIT ===');
      debugPrint(e.toString());
      debugPrint(stack.toString());
      if (state is HomeLoaded) return;
      emit(const HomeError("Impossible de charger les données de l'accueil."));
    }
  }

  List<TrackModel> _parseLocalRecentTracks(
    List<Map<String, dynamic>> entries, {
    int limit = 30,
  }) {
    final result = <TrackModel>[];
    final seen = <String>{};
    for (final entry in entries) {
      final rawTrack = entry['track'];
      if (rawTrack is! Map) continue;
      try {
        final track = TrackModel.fromJson(Map<String, dynamic>.from(rawTrack));
        final key = track.id.isNotEmpty
            ? track.id
            : '${track.title.toLowerCase()}_${track.artistName.toLowerCase()}';
        if (track.title.trim().isEmpty || !seen.add(key)) continue;
        result.add(track);
        if (result.length >= limit) break;
      } catch (_) {}
    }
    return result;
  }

  List<TrackModel> _mergeRecentTracks(
    List<TrackModel> primary,
    List<TrackModel> secondary, {
    int limit = 30,
  }) {
    final result = <TrackModel>[];
    final seen = <String>{};
    for (final track in [...primary, ...secondary]) {
      final key = track.id.isNotEmpty
          ? track.id
          : '${track.title.toLowerCase()}_${track.artistName.toLowerCase()}';
      if (track.title.trim().isEmpty || !seen.add(key)) continue;
      result.add(track);
      if (result.length >= limit) break;
    }
    return result;
  }

  Map<String, List<String>> _extract7DayProfile(
    List<Map<String, dynamic>> recent7dEntries,
    List<TrackModel> fallbackTracks,
    List<String> favoriteArtists,
  ) {
    final artistWeights = <String, int>{};
    final keywordWeights = <String, int>{};
    const stopWords = <String>{
      'feat', 'featuring', 'remix', 'prod', 'official', 'audio', 'video',
      'version', 'edit', 'radio', 'live', 'avec', 'dans', 'pour', 'sans',
      'from', 'with', 'that', 'this', 'your', 'love', 'part', 'song',
    };

    void addWords(String text, int weight) {
      final cleaned = text
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9àâäéèêëïîôöùûüç\s]'), ' ');
      for (final word in cleaned.split(RegExp(r'\s+'))) {
        if (word.length >= 4 && !stopWords.contains(word)) {
          keywordWeights[word] = (keywordWeights[word] ?? 0) + weight;
        }
      }
    }

    for (final entry in recent7dEntries) {
      final trackMap = entry['track'];
      if (trackMap is! Map) continue;
      final artist = (trackMap['artist_name'] ?? '').toString().trim();
      final title = (trackMap['title'] ?? '').toString();
      final album = (trackMap['album_name'] ?? '').toString();
      final rawCount = entry['recent_count'];
      final weight = (rawCount is int && rawCount > 0) ? rawCount : 1;
      if (artist.isNotEmpty) {
        artistWeights[artist] = (artistWeights[artist] ?? 0) + (weight * 3);
      }
      addWords(title, weight);
      addWords(album, weight);
    }

    if (artistWeights.isEmpty && fallbackTracks.isNotEmpty) {
      for (final track in fallbackTracks.take(15)) {
        final artist = track.artistName.trim();
        if (artist.isNotEmpty) {
          artistWeights[artist] = (artistWeights[artist] ?? 0) + 2;
        }
        addWords(track.title, 1);
        addWords(track.albumName, 1);
      }
    }

    for (final fav in favoriteArtists) {
      final trimmed = fav.trim();
      if (trimmed.isNotEmpty) {
        artistWeights[trimmed] = (artistWeights[trimmed] ?? 0) + 2;
      }
    }

    final sortedArtists = artistWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedKeywords = keywordWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'artists': sortedArtists.map((e) => e.key).take(10).toList(),
      'keywords': sortedKeywords.map((e) => e.key).take(8).toList(),
    };
  }

  /// Charge recommandations, similar tracks, et daily mixes sans bloquer l'UI
  Future<void> _loadSecondaryData({
    required List<String> favoriteArtistNames,
    required List<TrackModel> trendingTracks,
    required List<TrackModel> recentTrends,
    required String defaultMood,
  }) async {
    if (isClosed || state is! HomeLoaded) return;

    try {
      // Fill the non-critical home sections after the first content is already
      // visible, keeping the startup burst lightweight.
      final optionalResults = await Future.wait([
        catalogRepository.getGenres().catchError((_) => <Map<String, String>>[]),
        catalogRepository.getPodcasts(limit: 10).catchError((_) => <TrackModel>[]),
        catalogRepository.getTopArtists(limit: 20).catchError((_) => <Map<String, String>>[]),
        catalogRepository.getTracksByMood(defaultMood, limit: 25).catchError((_) => <TrackModel>[]),
        catalogRepository.getEditorialPlaylists(limit: 12).catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (isClosed || state is! HomeLoaded) return;

      final baseState = state as HomeLoaded;
      final genres = optionalResults[0] as List<Map<String, String>>;
      final podcastTracks = optionalResults[1] as List<TrackModel>;
      final topArtists = optionalResults[2] as List<Map<String, String>>;
      final moodTracks = optionalResults[3] as List<TrackModel>;
      final editorialPlaylists = optionalResults[4] as List<Map<String, dynamic>>;
      emit(baseState.copyWith(
        contextualTracks: moodTracks.isNotEmpty ? moodTracks : baseState.contextualTracks,
        moodTracks: moodTracks.isNotEmpty ? moodTracks : baseState.moodTracks,
        podcastTracks: podcastTracks,
        topArtists: topArtists,
        genres: genres,
        editorialPlaylists: editorialPlaylists.isNotEmpty ? editorialPlaylists : baseState.editorialPlaylists,
      ));

      final tasteProfile = buildUserTasteProfile(
        overrideFavorites: (state is HomeLoaded) ? (state as HomeLoaded).userFavorites : null,
      );

      // Charger recommandations, artistes similaires et Mix Énergique en parallèle
      final secondaryResults = await Future.wait([
        catalogRepository
            .getRecommendations(
              favoriteArtistNames,
              limit: 15,
              profile: tasteProfile,
            )
            .catchError((_) => <TrackModel>[]),
        _getSimilarArtistData(
          tasteProfile.topAnchorArtists.isNotEmpty
              ? tasteProfile.topAnchorArtists
              : favoriteArtistNames,
        ),
        catalogRepository.getEnergeticMixTracks(limit: 20)
            .catchError((_) => <TrackModel>[]),
      ]);

      if (isClosed || state is! HomeLoaded) return;

      final recommendations = secondaryResults[0] as List<TrackModel>;
      final similarData = secondaryResults[1] as Map<String, dynamic>;
      final energeticTracks = secondaryResults[2] as List<TrackModel>;
      final filteredMoodTracks = RecommendationEngine.rankTracksForProfile(
        moodTracks,
        tasteProfile,
        limit: 25,
        strictGate: !tasteProfile.isColdStart,
      );
      final effectiveMoodTracks =
          filteredMoodTracks.isNotEmpty ? filteredMoodTracks : moodTracks;

      final dailyMixes = await _buildDailyMixes(
        tasteProfile.topAnchorArtists.isNotEmpty
            ? tasteProfile.topAnchorArtists
            : favoriteArtistNames,
        trendingTracks,
        recentTrends,
        energeticTracks,
        recommendations,
      );

      if (isClosed || state is! HomeLoaded) return;
      final latestState = state as HomeLoaded;

      emit(latestState.copyWith(
        contextualTracks: recommendations.isNotEmpty
            ? recommendations
            : (effectiveMoodTracks.isNotEmpty
                ? effectiveMoodTracks
                : latestState.contextualTracks),
        moodTracks: effectiveMoodTracks.isNotEmpty
            ? effectiveMoodTracks
            : latestState.moodTracks,
        dailyMixes: dailyMixes.isNotEmpty ? dailyMixes : latestState.dailyMixes,
        similarToArtistName: similarData['name'] as String?,
        similarToArtistTracks: similarData['tracks'] as List<TrackModel>,
        recommendations: recommendations.isNotEmpty ? recommendations : latestState.recommendations,
        hasAfroAffinity: tasteProfile.hasAfroAffinity,
        hasUsPopAffinity: tasteProfile.hasUsPopHipHopAffinity,
      ));

      // ── CHARGEMENT DES TOPS RÉGIONAUX FILTRÉS PAR AFFINITÉ DU COMPTE ──
      final bool allowAfro = tasteProfile.hasAfroAffinity;
      final bool allowUsPop = tasteProfile.hasUsPopHipHopAffinity;

      final regionalResults = await Future.wait([
        allowAfro
            ? catalogRepository.getAfrobeatsPureTracks(limit: 30).catchError((_) => <TrackModel>[])
            : Future.value(<TrackModel>[]),
        allowAfro
            ? catalogRepository.getCameroonTopTracks(limit: 30).catchError((_) => <TrackModel>[])
            : Future.value(<TrackModel>[]),
        allowUsPop
            ? catalogRepository.getTopUsaTracks(limit: 20).catchError((_) => <TrackModel>[])
            : Future.value(<TrackModel>[]),
        catalogRepository.getContinentalChart('africa', limit: 30).catchError((_) => <TrackModel>[]),
      ]);

      if (isClosed || state is! HomeLoaded) return;

      final afrobeatsTracks = regionalResults[0];
      final cameroonTracks = regionalResults[1];
      final topUsaTracks = regionalResults[2];
      final africaTracks = regionalResults[3];

      final regionalState = state as HomeLoaded;
      final updatedCharts = Map<String, List<TrackModel>>.from(regionalState.continentalCharts);
      if (africaTracks.isNotEmpty) {
        updatedCharts['africa'] = africaTracks;
      }

      emit(regionalState.copyWith(
        afrobeatsTracks: allowAfro ? afrobeatsTracks : const [],
        cameroonTracks: allowAfro ? cameroonTracks : const [],
        topUsaTracks: allowUsPop ? topUsaTracks : const [],
        continentalCharts: updatedCharts,
        hasAfroAffinity: allowAfro,
        hasUsPopAffinity: allowUsPop,
      ));
    } catch (_) {
      // On garde l'état actuel, les données de base suffisent
    }
  }

  Future<Map<String, dynamic>> _getSimilarArtistData(List<String> favoriteArtistNames) async {
    if (favoriteArtistNames.isEmpty) {
      return {'name': null, 'tracks': <TrackModel>[]};
    }
    final randomArtistList = favoriteArtistNames.toList()..shuffle();
    final name = randomArtistList.first;
    final tracks = await catalogRepository.getSimilarTracks(name, limit: 10).catchError((_) => <TrackModel>[]);
    return {'name': name, 'tracks': tracks};
  }

  List<TrackModel> _dedupeAgainst(
    List<TrackModel> source,
    Set<String> usedIds,
    Set<String> usedKeys, {
    int limit = 10,
  }) {
    final result = <TrackModel>[];
    for (final t in source) {
      final key = '${t.title.toLowerCase()}__${t.artistName.toLowerCase()}';
      if (usedIds.contains(t.id) || usedKeys.contains(key)) continue;
      usedIds.add(t.id);
      usedKeys.add(key);
      result.add(t);
      if (result.length >= limit) break;
    }
    return result;
  }

  Future<Map<String, List<TrackModel>>> _buildDailyMixes(
    List<String> favoriteArtistNames,
    List<TrackModel> trendingTracks,
    List<TrackModel> recentTrends,
    List<TrackModel> energeticTracks,
    List<TrackModel> recommendations,
  ) async {
    Map<String, List<TrackModel>> dailyMixes = {};
    
    if (favoriteArtistNames.isNotEmpty && favoriteArtistNames.length >= 2) {
      final shuffledFavorites = favoriteArtistNames.toList()..shuffle();
      // Charger les 3 mixes en parallèle au lieu de séquentiellement
      final mixFutures = <Future<MapEntry<String, List<TrackModel>>>>[];
      for (int i = 0; i < 3 && i < shuffledFavorites.length; i++) {
        final artist = shuffledFavorites[i];
        mixFutures.add(
          catalogRepository.getSimilarTracks(artist, limit: 15)
              .catchError((_) => <TrackModel>[])
              .then((tracks) => MapEntry("Mix $artist", tracks)),
        );
      }
      final mixResults = await Future.wait(mixFutures);
      for (final entry in mixResults) {
        if (entry.value.isNotEmpty) {
          dailyMixes[entry.key] = entry.value;
        }
      }
    }
    
    // Fallback Daily Mixes distincts si pas assez de favoris
    if (dailyMixes.isEmpty) {
      final usedIds = <String>{};
      final usedKeys = <String>{};

      if (trendingTracks.isNotEmpty) {
        final pop = _dedupeAgainst(trendingTracks, usedIds, usedKeys, limit: 10);
        if (pop.isNotEmpty) {
          dailyMixes["Mix Populaire"] = pop;
        }
      }
      if (recentTrends.isNotEmpty) {
        final disc = _dedupeAgainst(recentTrends, usedIds, usedKeys, limit: 10);
        if (disc.isNotEmpty) {
          dailyMixes["Mix Découvertes"] = disc;
        }
      }
      final energyPool = energeticTracks.isNotEmpty ? energeticTracks : recommendations;
      if (energyPool.isNotEmpty) {
        final energy = _dedupeAgainst(energyPool, usedIds, usedKeys, limit: 10);
        if (energy.isNotEmpty) {
          dailyMixes["Mix Énergique"] = energy;
        }
      }
    }
    
    return dailyMixes;
  }

  Future<void> saveFavoriteArtists(List<String> artists) async {
    await storageService.saveFavoriteArtists(artists);
    await storageService.clearWeeklyPlaylistsCache();
    await loadHomeData(forceRefresh: true);
  }

  /// Sélection dynamique d'une Ambiance du Quotidien (Soirée, Nocturne, Sport, Détente, Focus, Trajet)
  Future<void> selectMood(String moodId) async {
    if (state is! HomeLoaded) return;
    final currentState = state as HomeLoaded;
    if (currentState.selectedMood == moodId && currentState.moodTracks.isNotEmpty) return;

    emit(currentState.copyWith(
      selectedMood: moodId,
      isFilteringMood: false,
      isMoodLoading: true,
    ));

    try {
      final tracks = await catalogRepository.getTracksByMood(moodId, limit: 25);
      if (isClosed || state is! HomeLoaded) return;
      final latest = state as HomeLoaded;
      if (latest.selectedMood == moodId) {
        emit(latest.copyWith(
          moodTracks: tracks.isNotEmpty ? tracks : latest.moodTracks,
          isMoodLoading: false,
        ));
      }
    } catch (_) {
      if (isClosed || state is! HomeLoaded) return;
      final latest = state as HomeLoaded;
      if (latest.selectedMood == moodId) {
        emit(latest.copyWith(
          isMoodLoading: false,
        ));
      }
    }
  }

  /// Sélection d'un continent pour le Hub des Tops Continentaux
  Future<void> selectContinent(String continentKey) async {
    if (state is! HomeLoaded) return;
    final currentState = state as HomeLoaded;

    if (currentState.continentalCharts.containsKey(continentKey) &&
        currentState.continentalCharts[continentKey]!.isNotEmpty) {
      emit(currentState.copyWith(
        selectedContinent: continentKey,
        isContinentLoading: false,
      ));
      return;
    }

    emit(currentState.copyWith(
      selectedContinent: continentKey,
      isContinentLoading: true,
    ));

    try {
      final tracks = await catalogRepository.getContinentalChart(continentKey, limit: 30);
      if (isClosed || state is! HomeLoaded) return;
      final latest = state as HomeLoaded;
      final updated = Map<String, List<TrackModel>>.from(latest.continentalCharts);
      updated[continentKey] = tracks;
      emit(latest.copyWith(
        selectedContinent: continentKey,
        isContinentLoading: false,
        continentalCharts: updated,
      ));
    } catch (_) {
      if (isClosed || state is! HomeLoaded) return;
      final latest = state as HomeLoaded;
      emit(latest.copyWith(isContinentLoading: false));
    }
  }
}
