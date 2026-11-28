import 'dart:async';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:home_widget/home_widget.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/storage/json_cache.dart';
import '../../data/repositories/library_repository.dart';
import '../../../player/data/models/track_model.dart';
import 'library_state.dart';

class WrappedTrackItem {
  final TrackModel track;
  final int playCount;

  const WrappedTrackItem({
    required this.track,
    required this.playCount,
  });
}

class LibraryCubit extends Cubit<LibraryState> {
  final LibraryRepository repository;
  final String Function()? _cacheKeyProvider;

  int _loadEpoch = 0;
  int _activeLoads = 0;
  Future<void>? _ongoingLoad;
  DateTime? _lastSuccessfulLoadAt;

  // Protège les créations, modifications et suppressions concurrentes pendant un chargement réseau.
  final Map<int, int> _resolvedPlaylistIds = {};
  final Set<int> _recentlySyncedPlaylistIds = {};
  final Set<int> _recentlyDeletedPlaylistIds = {};
  final Set<int> _mutatedDuringLoadIds = {};
  final Set<int> _syncingLocalPlaylistIds = {};

  LibraryCubit({
    required this.repository,
    String Function()? cacheKeyProvider,
  })  : _cacheKeyProvider = cacheKeyProvider,
        super(LibraryInitial());

  String get _cacheKey =>
      _cacheKeyProvider?.call() ??
      'library_v2_${StorageService().accountScope}';

  /// Retourne l'ID serveur résolu si la playlist a été créée localement avec un ID négatif.
  int resolvePlaylistId(int playlistId) => _resolvedPlaylistIds[playlistId] ?? playlistId;

  List<PlaylistModel> _sortPlaylists(List<PlaylistModel> playlists) {
    final pinned = playlists.where((p) => p.isPinned).toList();
    final unpinned = playlists.where((p) => !p.isPinned).toList();
    return [...pinned, ...unpinned];
  }

  String _historyIdentityKey(HistoryModel item) {
    final t = item.track;
    if (t != null) {
      final cleanTitle = t.title.trim().toLowerCase();
      final cleanArtist = t.artistName.trim().toLowerCase();
      if (cleanTitle.isNotEmpty && cleanArtist.isNotEmpty) {
        return 'meta:${cleanTitle}__$cleanArtist';
      }
      if (t.id.trim().isNotEmpty) {
        return 'id:${t.id.trim()}';
      }
    }
    return 'id:${item.trackId.trim()}';
  }

  /// Trie l'historique du plus récent au plus ancien et ne conserve chaque son qu'une seule fois.
  List<HistoryModel> _deduplicateHistory(List<HistoryModel> raw) {
    if (raw.isEmpty) return const [];
    final indexed = raw.asMap().entries.toList();
    indexed.sort((a, b) {
      final dtA = DateTime.tryParse(a.value.playedAt)?.millisecondsSinceEpoch ?? 0;
      final dtB = DateTime.tryParse(b.value.playedAt)?.millisecondsSinceEpoch ?? 0;
      if (dtB != dtA) return dtB.compareTo(dtA);
      return a.key.compareTo(b.key);
    });

    final seen = <String>{};
    final result = <HistoryModel>[];
    for (final entry in indexed) {
      final key = _historyIdentityKey(entry.value);
      if (seen.add(key)) {
        result.add(entry.value);
      }
    }
    return result;
  }

  List<FavoriteAlbumModel> _readSavedFavoriteAlbums() {
    try {
      return StorageService()
          .getFavoriteAlbumsRaw()
          .map((e) => FavoriteAlbumModel.fromJson(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveCache(
    LibraryLoaded s, {
    bool syncFavoriteAlbums = false,
  }) async {
    await StorageService().saveFavoriteAlbumsRaw(
      s.favoriteAlbums.map((a) => a.toJson()).toList(),
      syncToServer: syncFavoriteAlbums,
    );
    await JsonCache.write(_cacheKey, {
      'favorites': s.favorites.map((t) => t.toJson()).toList(),
      'favorite_albums': s.favoriteAlbums.map((a) => a.toJson()).toList(),
      'playlists': s.playlists
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'cover_url': p.coverUrl,
                'tracks_count': p.tracksCount,
                'is_pinned': p.isPinned,
                'tracks': p.tracks.map((t) => {'track_details': t.toJson()}).toList(),
              })
          .toList(),
      'history': s.history
          .where((h) => h.track != null)
          .map((h) => {
                'id': h.id,
                'track_id': h.trackId,
                'played_at': h.playedAt,
                'track_details': h.track!.toJson(),
              })
          .toList(),
    });
  }

  Future<void> _updateStateAndCache(
    LibraryLoaded newState, {
    bool syncFavoriteAlbums = false,
  }) async {
    if (isClosed) return;
    emit(newState);
    await _saveCache(newState, syncFavoriteAlbums: syncFavoriteAlbums);
  }

  Future<LibraryLoaded?> _readCache() async {
    try {
      final data = await JsonCache.read(_cacheKey);
      if (data is! Map) return null;
      final savedAlbums = _readSavedFavoriteAlbums();
      final cachedAlbums = (data['favorite_albums'] as List? ?? [])
          .whereType<Map>()
          .map((e) => FavoriteAlbumModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final albums = savedAlbums.isNotEmpty ? savedAlbums : cachedAlbums;
      return LibraryLoaded(
        favorites: (data['favorites'] as List? ?? [])
            .map((e) => TrackModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        playlists: _sortPlaylists((data['playlists'] as List? ?? [])
            .map((e) => PlaylistModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()),
        history: _deduplicateHistory((data['history'] as List? ?? [])
            .map((e) => HistoryModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()),
        favoriteAlbums: albums,
      );
    } catch (_) {
      return null;
    }
  }

  void _markPlaylistMutated(int playlistId) {
    if (_activeLoads > 0) {
      _mutatedDuringLoadIds.add(playlistId);
      _mutatedDuringLoadIds.add(resolvePlaylistId(playlistId));
    }
  }

  List<PlaylistModel> _mergeLoadedPlaylists({
    required List<PlaylistModel> remotePlaylists,
    required List<PlaylistModel> currentLocalPlaylists,
    required bool remoteFetched,
  }) {
    if (!remoteFetched) {
      return _sortPlaylists(
        currentLocalPlaylists
            .where((p) => !_recentlyDeletedPlaylistIds.contains(p.id))
            .toList(),
      );
    }

    final currentById = <int, PlaylistModel>{
      for (final p in currentLocalPlaylists) p.id: p,
    };

    final merged = <PlaylistModel>[];
    final seenIds = <int>{};

    // 1. Conserver d'abord les playlists purement locales en attente de synchro.
    for (final local in currentLocalPlaylists) {
      if (local.id < 0 &&
          !_recentlyDeletedPlaylistIds.contains(local.id) &&
          !_resolvedPlaylistIds.containsKey(local.id)) {
        if (seenIds.add(local.id)) {
          merged.add(local);
        }
      }
    }

    // 2. Intégrer les playlists distantes en protégeant celles modifiées pendant le fetch.
    for (final remote in remotePlaylists) {
      if (_recentlyDeletedPlaylistIds.contains(remote.id)) continue;
      final existing = currentById[remote.id];
      if (existing != null && _mutatedDuringLoadIds.contains(remote.id)) {
        if (seenIds.add(existing.id)) {
          merged.add(existing);
        }
        continue;
      }
      final preservedCover =
          (remote.coverUrl.isEmpty && existing != null && existing.coverUrl.isNotEmpty)
              ? existing.coverUrl
              : remote.coverUrl;
      if (seenIds.add(remote.id)) {
        merged.add(remote.copyWith(coverUrl: preservedCover));
      }
    }

    // 3. Préserver les playlists créées pendant que getPlaylists() était encore en cours.
    for (final local in currentLocalPlaylists) {
      if (local.id > 0 &&
          (_recentlySyncedPlaylistIds.contains(local.id) ||
              _mutatedDuringLoadIds.contains(local.id)) &&
          !_recentlyDeletedPlaylistIds.contains(local.id) &&
          seenIds.add(local.id)) {
        merged.insert(0, local);
      }
    }

    return _sortPlaylists(merged);
  }

  Future<void> _syncPendingLocalPlaylists(List<PlaylistModel> playlists) async {
    final pending = playlists
        .where((p) =>
            p.id < 0 &&
            !_resolvedPlaylistIds.containsKey(p.id) &&
            !_recentlyDeletedPlaylistIds.contains(p.id) &&
            !_syncingLocalPlaylistIds.contains(p.id))
        .toList();

    for (final local in pending) {
      if (isClosed) return;
      _syncingLocalPlaylistIds.add(local.id);
      try {
        final serverCover = local.coverUrl.startsWith('file://')
            ? local.coverUrl.replaceFirst('file://', 'http://local.image/')
            : local.coverUrl;
        final created = await repository.createPlaylist(local.name, coverUrl: serverCover);
        _resolvedPlaylistIds[local.id] = created.id;
        _recentlySyncedPlaylistIds.add(created.id);

        PlaylistModel liveLocal = local;
        if (state is LibraryLoaded) {
          for (final p in (state as LibraryLoaded).playlists) {
            if (p.id == local.id) {
              liveLocal = p;
              break;
            }
          }
        }

        for (final track in liveLocal.tracks) {
          try {
            await repository.addTrackToPlaylist(created.id, track);
          } catch (_) {}
        }
        if (liveLocal.isPinned) {
          try {
            await repository.updatePlaylist(created.id, isPinned: true);
          } catch (_) {}
        }

        final hydrated = created.copyWith(
          name: liveLocal.name,
          coverUrl: created.coverUrl.isNotEmpty ? created.coverUrl : liveLocal.coverUrl,
          isPinned: liveLocal.isPinned,
          tracks: liveLocal.tracks,
          tracksCount: liveLocal.tracks.isNotEmpty ? liveLocal.tracks.length : created.tracksCount,
        );

        if (state is LibraryLoaded) {
          final loadedState = state as LibraryLoaded;
          final updated = loadedState.playlists
              .map((p) => p.id == local.id ? hydrated : p)
              .toList();
          await _updateStateAndCache(loadedState.copyWith(playlists: _sortPlaylists(updated)));
        }
      } catch (_) {
        // Toujours hors-ligne : on réessaiera au prochain chargement.
      } finally {
        _syncingLocalPlaylistIds.remove(local.id);
      }
    }
  }

  /// Charge la bibliothèque sans jamais bloquer l'écran :
  /// - données déjà en mémoire -> on les garde affichées et on rafraîchit en silence ;
  /// - sinon, dernier contenu connu depuis le disque -> affiché instantanément ;
  /// - le spinner n'apparaît qu'au tout premier lancement (aucune donnée connue)
  ///   ou si [forceFresh] est demandé (ex : changement de compte).
  Future<void> loadLibraryData({bool forceFresh = false}) async {
    if (!forceFresh && _ongoingLoad != null) {
      return _ongoingLoad!;
    }

    if (!forceFresh && _lastSuccessfulLoadAt != null && state is LibraryLoaded) {
      final hasPendingLocal = (state as LibraryLoaded).playlists.any((p) => p.id < 0);
      if (!hasPendingLocal &&
          DateTime.now().difference(_lastSuccessfulLoadAt!).inSeconds < 5) {
        return;
      }
    }

    final future = _executeLoadLibraryData(forceFresh: forceFresh);
    _ongoingLoad = future;
    try {
      await future;
    } finally {
      if (identical(_ongoingLoad, future)) {
        _ongoingLoad = null;
      }
    }
  }

  Future<void> _executeLoadLibraryData({required bool forceFresh}) async {
    if (forceFresh) {
      _loadEpoch++;
      _resolvedPlaylistIds.clear();
      _recentlySyncedPlaylistIds.clear();
      _recentlyDeletedPlaylistIds.clear();
      _mutatedDuringLoadIds.clear();
      emit(LibraryLoading());
    } else if (state is! LibraryLoaded) {
      final cached = await _readCache();
      if (isClosed) return;
      emit(cached ?? LibraryLoading());
    }

    final int epoch = _loadEpoch;
    _activeLoads++;
    try {
      final previous = state is LibraryLoaded ? state as LibraryLoaded : null;

      bool favoritesOk = false;
      bool playlistsOk = false;
      bool historyOk = false;
      List<TrackModel>? remoteFavorites;
      List<PlaylistModel>? remotePlaylists;
      List<HistoryModel>? remoteHistory;

      await Future.wait([
        () async {
          try {
            remoteFavorites = await repository.getFavorites();
            favoritesOk = true;
          } catch (_) {}
        }(),
        () async {
          try {
            remotePlaylists = await repository.getPlaylists();
            playlistsOk = true;
          } catch (_) {}
        }(),
        () async {
          try {
            remoteHistory = await repository.getHistory();
            historyOk = true;
          } catch (_) {}
        }(),
      ]);

      if (isClosed || epoch != _loadEpoch) return;

      // Relire l'état le plus récent au moment de l'émission pour ne jamais écraser
      // une playlist créée ou modifiée pendant les requêtes réseau.
      final latestLoaded = state is LibraryLoaded ? state as LibraryLoaded : previous;

      // Si toutes les requêtes distantes ont échoué et qu'aucun cache local n'existe,
      // signaler l'erreur au lieu d'afficher une bibliothèque faussement vide.
      if (!favoritesOk && !playlistsOk && !historyOk && latestLoaded == null) {
        emit(const LibraryError(
          "Impossible de charger votre bibliothèque pour le moment. Vérifiez votre connexion et réessayez.",
        ));
        return;
      }

      final favorites = remoteFavorites ?? latestLoaded?.favorites ?? [];
      final history = _deduplicateHistory(
        remoteHistory ?? latestLoaded?.history ?? [],
      );
      final savedAlbums = _readSavedFavoriteAlbums();
      final favoriteAlbums = savedAlbums.isNotEmpty
          ? savedAlbums
          : (latestLoaded?.favoriteAlbums ?? const []);
      final playlists = _mergeLoadedPlaylists(
        remotePlaylists: remotePlaylists ?? const [],
        currentLocalPlaylists: latestLoaded?.playlists ?? const [],
        remoteFetched: playlistsOk,
      );

      final loaded = LibraryLoaded(
        favorites: favorites,
        playlists: playlists,
        history: history,
        favoriteAlbums: favoriteAlbums,
      );
      emit(loaded);
      await _saveCache(loaded);

      if (playlistsOk && favoritesOk) {
        _lastSuccessfulLoadAt = DateTime.now();
      }
      if (playlistsOk) {
        unawaited(_syncPendingLocalPlaylists(playlists));
      }
    } catch (e, stack) {
      print("Erreur complète: $e\n$stack");
      if (state is LibraryLoaded || isClosed || epoch != _loadEpoch) return;
      emit(LibraryError("Une erreur est survenue lors du chargement de votre bibliothèque.\n\nDétail: $e"));
    } finally {
      _activeLoads = (_activeLoads > 0) ? _activeLoads - 1 : 0;
      if (_activeLoads == 0) {
        _mutatedDuringLoadIds.clear();
      }
    }
  }

  Future<PlaylistModel> createPlaylist(
    String name, {
    String coverUrl = '',
    void Function(PlaylistModel)? onOptimisticCreated,
  }) async {
    final existingIds = state is LibraryLoaded
        ? (state as LibraryLoaded).playlists.map((p) => p.id).toSet()
        : <int>{};
    int tempId = -DateTime.now().millisecondsSinceEpoch;
    while (existingIds.contains(tempId)) {
      tempId--;
    }

    String normalizedCover = coverUrl;
    if (normalizedCover.startsWith('http://local.image/')) {
      normalizedCover = normalizedCover.replaceFirst('http://local.image/', 'file://');
    }
    final localPlaylist = PlaylistModel(
      id: tempId,
      name: name,
      coverUrl: normalizedCover,
      tracksCount: 0,
      isPinned: false,
      tracks: const [],
    );

    _markPlaylistMutated(tempId);

    if (state is LibraryLoaded) {
      final loadedState = state as LibraryLoaded;
      final updatedPlaylists = List<PlaylistModel>.from(loadedState.playlists)..insert(0, localPlaylist);
      await _updateStateAndCache(loadedState.copyWith(playlists: _sortPlaylists(updatedPlaylists)));
    } else {
      final loadedState = LibraryLoaded(
        favorites: const [],
        playlists: [localPlaylist],
        history: const [],
      );
      await _updateStateAndCache(loadedState);
    }

    onOptimisticCreated?.call(localPlaylist);

    try {
      final created = await repository.createPlaylist(name, coverUrl: coverUrl);
      _resolvedPlaylistIds[tempId] = created.id;
      _recentlySyncedPlaylistIds.add(created.id);
      _markPlaylistMutated(created.id);

      PlaylistModel resultPlaylist = created.copyWith(
        coverUrl: created.coverUrl.isNotEmpty ? created.coverUrl : normalizedCover,
      );

      if (state is LibraryLoaded) {
        final loadedState = state as LibraryLoaded;
        PlaylistModel? liveLocal;
        for (final p in loadedState.playlists) {
          if (p.id == tempId) {
            liveLocal = p;
            break;
          }
        }

        if (liveLocal != null) {
          resultPlaylist = resultPlaylist.copyWith(
            name: liveLocal.name,
            coverUrl: resultPlaylist.coverUrl.isNotEmpty ? resultPlaylist.coverUrl : liveLocal.coverUrl,
            isPinned: liveLocal.isPinned,
            tracks: liveLocal.tracks.isNotEmpty ? liveLocal.tracks : resultPlaylist.tracks,
            tracksCount: liveLocal.tracks.isNotEmpty ? liveLocal.tracks.length : resultPlaylist.tracksCount,
          );
          // Pousser les morceaux/épinglage éventuellement ajoutés avant le retour du POST.
          for (final track in liveLocal.tracks) {
            repository.addTrackToPlaylist(created.id, track).catchError((_) {});
          }
          if (liveLocal.isPinned) {
            repository.updatePlaylist(created.id, isPinned: true).catchError((_) => resultPlaylist);
          }
        }

        final updatedPlaylists = loadedState.playlists.any((p) => p.id == tempId)
            ? loadedState.playlists.map((p) => p.id == tempId ? resultPlaylist : p).toList()
            : [resultPlaylist, ...loadedState.playlists.where((p) => p.id != created.id)];

        await _updateStateAndCache(loadedState.copyWith(playlists: _sortPlaylists(updatedPlaylists)));
      }
      return resultPlaylist;
    } catch (e) {
      print("Erreur création playlist sur le serveur (conservée en local): $e");
      return localPlaylist;
    }
  }

  Future<void> deletePlaylist(int playlistId) async {
    final effectiveId = resolvePlaylistId(playlistId);
    _recentlyDeletedPlaylistIds.add(playlistId);
    _recentlyDeletedPlaylistIds.add(effectiveId);

    if (state is LibraryLoaded) {
      final loadedState = state as LibraryLoaded;
      final updatedPlaylists = loadedState.playlists
          .where((p) => p.id != playlistId && p.id != effectiveId)
          .toList();
      await _updateStateAndCache(loadedState.copyWith(playlists: updatedPlaylists));
    }
    if (effectiveId > 0) {
      try {
        await repository.deletePlaylist(effectiveId);
      } catch (_) {}
    }
  }

  Future<void> togglePinPlaylist(int playlistId, bool currentPinState) async {
    final effectiveId = resolvePlaylistId(playlistId);
    _markPlaylistMutated(playlistId);

    if (state is LibraryLoaded) {
      final loadedState = state as LibraryLoaded;
      final updatedPlaylists = loadedState.playlists.map((p) {
        if (p.id == playlistId || p.id == effectiveId) {
          return p.copyWith(isPinned: !currentPinState);
        }
        return p;
      }).toList();
      await _updateStateAndCache(loadedState.copyWith(playlists: _sortPlaylists(updatedPlaylists)));
    }
    if (effectiveId > 0) {
      try {
        await repository.updatePlaylist(effectiveId, isPinned: !currentPinState);
      } catch (_) {}
    }
  }

  Future<void> updatePlaylistDetails(int playlistId, {String? name, String? coverUrl}) async {
    final effectiveId = resolvePlaylistId(playlistId);
    _markPlaylistMutated(playlistId);

    if (state is LibraryLoaded) {
      final loadedState = state as LibraryLoaded;
      final updatedPlaylists = loadedState.playlists.map((p) {
        if (p.id == playlistId || p.id == effectiveId) {
          String normalizedCover = coverUrl ?? p.coverUrl;
          if (normalizedCover.startsWith('http://local.image/')) {
            normalizedCover = normalizedCover.replaceFirst('http://local.image/', 'file://');
          }
          return p.copyWith(
            name: name ?? p.name,
            coverUrl: normalizedCover,
          );
        }
        return p;
      }).toList();
      await _updateStateAndCache(loadedState.copyWith(playlists: updatedPlaylists));
    }
    if (effectiveId > 0) {
      try {
        await repository.updatePlaylist(effectiveId, name: name, coverUrl: coverUrl);
      } catch (_) {}
    }
  }

  Future<void> addTrackToPlaylist(int playlistId, TrackModel track) async {
    final effectiveId = resolvePlaylistId(playlistId);
    _markPlaylistMutated(playlistId);

    // Mise à jour optimiste instantanée en mémoire et persistance disque
    if (state is LibraryLoaded) {
      final loadedState = state as LibraryLoaded;
      final updatedPlaylists = loadedState.playlists.map((p) {
        if (p.id == playlistId || p.id == effectiveId) {
          final alreadyExists = p.tracks.any((t) => t.id == track.id);
          if (alreadyExists) return p;
          final updatedTracks = List<TrackModel>.from(p.tracks)..add(track);
          return p.copyWith(
            tracks: updatedTracks,
            tracksCount: updatedTracks.length,
          );
        }
        return p;
      }).toList();
      await _updateStateAndCache(loadedState.copyWith(playlists: updatedPlaylists));
    }

    if (effectiveId > 0) {
      repository.addTrackToPlaylist(effectiveId, track).catchError((e) {
        print("Erreur addTrackToPlaylist: $e");
      });
    }
  }

  Future<void> addMultipleTracksToPlaylist(int playlistId, List<TrackModel> tracks) async {
    final effectiveId = resolvePlaylistId(playlistId);
    _markPlaylistMutated(playlistId);

    if (state is LibraryLoaded) {
      final loadedState = state as LibraryLoaded;
      final updatedPlaylists = loadedState.playlists.map((p) {
        if (p.id == playlistId || p.id == effectiveId) {
          final updatedTracks = List<TrackModel>.from(p.tracks);
          for (final track in tracks) {
            if (!updatedTracks.any((t) => t.id == track.id)) {
              updatedTracks.add(track);
            }
          }
          return p.copyWith(
            tracks: updatedTracks,
            tracksCount: updatedTracks.length,
          );
        }
        return p;
      }).toList();
      await _updateStateAndCache(loadedState.copyWith(playlists: updatedPlaylists));
    }

    if (effectiveId > 0) {
      for (var track in tracks) {
        repository.addTrackToPlaylist(effectiveId, track).catchError((e) {
          print("Erreur addMultipleTracksToPlaylist: $e");
        });
      }
    }
  }

  Future<void> removeTrackFromPlaylist(int playlistId, String trackId) async {
    final effectiveId = resolvePlaylistId(playlistId);
    _markPlaylistMutated(playlistId);

    if (state is LibraryLoaded) {
      final loadedState = state as LibraryLoaded;
      final updatedPlaylists = loadedState.playlists.map((p) {
        if (p.id == playlistId || p.id == effectiveId) {
          final updatedTracks = p.tracks.where((t) => t.id != trackId).toList();
          return p.copyWith(
            tracks: updatedTracks,
            tracksCount: updatedTracks.length,
          );
        }
        return p;
      }).toList();
      await _updateStateAndCache(loadedState.copyWith(playlists: updatedPlaylists));
    }
    if (effectiveId > 0) {
      try {
        await repository.removeTrackFromPlaylist(effectiveId, trackId);
      } catch (_) {}
    }
  }

  /// Réorganise les morceaux d'une playlist par glisser-déposer (Drag-and-Drop) et sauvegarde l'ordre.
  Future<void> reorderPlaylistTracks(
    int playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    final effectiveId = resolvePlaylistId(playlistId);
    _markPlaylistMutated(playlistId);

    if (state is LibraryLoaded) {
      final loadedState = state as LibraryLoaded;
      final updatedPlaylists = loadedState.playlists.map((p) {
        if (p.id == playlistId || p.id == effectiveId) {
          final updatedTracks = List<TrackModel>.from(p.tracks);
          if (oldIndex < 0 || oldIndex >= updatedTracks.length) return p;
          int targetIdx = newIndex;
          if (oldIndex < targetIdx) {
            targetIdx -= 1;
          }
          targetIdx = targetIdx.clamp(0, updatedTracks.length - 1);
          final moved = updatedTracks.removeAt(oldIndex);
          updatedTracks.insert(targetIdx, moved);
          return p.copyWith(
            tracks: updatedTracks,
            tracksCount: updatedTracks.length,
          );
        }
        return p;
      }).toList();
      await _updateStateAndCache(
        loadedState.copyWith(playlists: updatedPlaylists),
      );
    }
  }

  Future<void> addFavorite(TrackModel track) async {
    if (state is LibraryLoaded) {
      final loadedState = state as LibraryLoaded;
      if (!loadedState.favorites.any((t) => t.id == track.id)) {
        final newFavorites = List<TrackModel>.from(loadedState.favorites)..insert(0, track);
        await _updateStateAndCache(loadedState.copyWith(favorites: newFavorites));
      }
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await HomeWidget.saveWidgetData<bool>('isFavorite', true);
        await HomeWidget.updateWidget(androidName: 'NowPlayingWidgetProvider');
        await HomeWidget.updateWidget(androidName: 'PlaylistWidgetProvider');
      } catch (_) {}
    }
    try {
      await repository.addFavorite(track);
    } catch (_) {}
  }

  Future<void> removeFavorite(String trackId) async {
    if (state is LibraryLoaded) {
      final loadedState = state as LibraryLoaded;
      final newFavorites = loadedState.favorites.where((t) => t.id != trackId).toList();
      await _updateStateAndCache(loadedState.copyWith(favorites: newFavorites));
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await HomeWidget.saveWidgetData<bool>('isFavorite', false);
        await HomeWidget.updateWidget(androidName: 'NowPlayingWidgetProvider');
        await HomeWidget.updateWidget(androidName: 'PlaylistWidgetProvider');
      } catch (_) {}
    }
    try {
      await repository.removeFavorite(trackId);
    } catch (_) {}
  }

  Future<void> addFavoritesBatch(List<TrackModel> tracks) async {
    if (tracks.isEmpty) return;
    final toSync = <TrackModel>[];

    if (state is LibraryLoaded) {
      final loadedState = state as LibraryLoaded;
      final existingKeys = <String>{};
      for (final f in loadedState.favorites) {
        existingKeys.add('id:${f.id}');
        final t = f.title.trim().toLowerCase();
        final a = f.artistName.trim().toLowerCase();
        if (t.isNotEmpty && a.isNotEmpty) {
          existingKeys.add('meta:${t}__$a');
        }
      }

      final inserted = <TrackModel>[];
      for (final track in tracks) {
        final tKey = 'meta:${track.title.trim().toLowerCase()}__${track.artistName.trim().toLowerCase()}';
        final already = existingKeys.contains('id:${track.id}') ||
            (track.title.trim().isNotEmpty &&
                track.artistName.trim().isNotEmpty &&
                existingKeys.contains(tKey));
        if (!already) {
          existingKeys.add('id:${track.id}');
          existingKeys.add(tKey);
          inserted.add(track);
          toSync.add(track);
        }
      }

      if (inserted.isNotEmpty) {
        final newFavorites = <TrackModel>[...inserted, ...loadedState.favorites];
        await _updateStateAndCache(loadedState.copyWith(favorites: newFavorites));
      }
    } else {
      toSync.addAll(tracks);
    }

    for (final track in toSync) {
      try {
        await repository.addFavorite(track);
      } catch (_) {}
    }
  }

  bool isAlbumFavorite({
    String? albumId,
    required String title,
    required String artistName,
  }) {
    final targetKey = FavoriteAlbumModel.computeIdentityKey(
      id: albumId,
      title: title,
      artistName: artistName,
    );
    final metaKey = FavoriteAlbumModel.computeIdentityKey(
      id: null,
      title: title,
      artistName: artistName,
    );
    final List<FavoriteAlbumModel> albums = state is LibraryLoaded
        ? (state as LibraryLoaded).favoriteAlbums
        : _readSavedFavoriteAlbums();
    return albums.any((a) =>
        a.identityKey == targetKey ||
        FavoriteAlbumModel.computeIdentityKey(
              id: null,
              title: a.title,
              artistName: a.artistName,
            ) ==
            metaKey);
  }

  Future<bool> toggleFavoriteAlbum({
    String? albumId,
    required String title,
    required String artistName,
    required String coverUrl,
    String year = '',
    required List<TrackModel> albumTracks,
  }) async {
    final targetKey = FavoriteAlbumModel.computeIdentityKey(
      id: albumId,
      title: title,
      artistName: artistName,
    );
    final metaKey = FavoriteAlbumModel.computeIdentityKey(
      id: null,
      title: title,
      artistName: artistName,
    );

    final loadedState = state is LibraryLoaded
        ? state as LibraryLoaded
        : LibraryLoaded(
            favorites: const [],
            playlists: const [],
            history: const [],
            favoriteAlbums: _readSavedFavoriteAlbums(),
          );

    final alreadyLiked = loadedState.favoriteAlbums.any((a) =>
        a.identityKey == targetKey ||
        FavoriteAlbumModel.computeIdentityKey(
              id: null,
              title: a.title,
              artistName: a.artistName,
            ) ==
            metaKey);

    if (alreadyLiked) {
      final updatedAlbums = loadedState.favoriteAlbums
          .where((a) =>
              a.identityKey != targetKey &&
              FavoriteAlbumModel.computeIdentityKey(
                    id: null,
                    title: a.title,
                    artistName: a.artistName,
                  ) !=
                  metaKey)
          .toList();
      await _updateStateAndCache(
        loadedState.copyWith(favoriteAlbums: updatedAlbums),
        syncFavoriteAlbums: true,
      );
      return false;
    }

    final newAlbum = FavoriteAlbumModel(
      id: (albumId ?? '').trim(),
      title: title.trim().isNotEmpty ? title.trim() : 'Album',
      artistName: artistName.trim().isNotEmpty ? artistName.trim() : 'Artiste',
      coverUrl: coverUrl,
      year: year,
      tracksCount: albumTracks.length,
      tracks: albumTracks,
      addedAt: DateTime.now().toIso8601String(),
    );

    final updatedAlbums = [newAlbum, ...loadedState.favoriteAlbums];
    await _updateStateAndCache(
      loadedState.copyWith(favoriteAlbums: updatedAlbums),
      syncFavoriteAlbums: true,
    );
    unawaited(addFavoritesBatch(albumTracks));
    return true;
  }

  Future<void> syncPendingLocalPlaylistsNow() async {
    if (state is LibraryLoaded) {
      final playlists = (state as LibraryLoaded).playlists;
      if (playlists.any((p) => p.id < 0)) {
        await _syncPendingLocalPlaylists(playlists);
      }
    }
  }

  void resetSessionState() {
    _loadEpoch++;
    _ongoingLoad = null;
    _lastSuccessfulLoadAt = null;
    _resolvedPlaylistIds.clear();
    _recentlySyncedPlaylistIds.clear();
    _recentlyDeletedPlaylistIds.clear();
    _mutatedDuringLoadIds.clear();
    _syncingLocalPlaylistIds.clear();
    if (!isClosed) {
      emit(LibraryInitial());
    }
  }

  bool isFavorite(String trackId, {String? title, String? artist}) {
    if (state is LibraryLoaded) {
      final loadedState = state as LibraryLoaded;
      return loadedState.favorites.any((track) {
        if (track.id == trackId) return true;
        if (title != null && artist != null && title.isNotEmpty && artist.isNotEmpty) {
          if (track.title.trim().toLowerCase() == title.trim().toLowerCase() &&
              track.artistName.trim().toLowerCase() == artist.trim().toLowerCase()) {
            return true;
          }
        }
        return false;
      });
    }
    return false;
  }

  void addHistoryRecordLocal(TrackModel track) {
    // Enregistrer dans le compteur cumulatif depuis la création du compte
    StorageService().recordLifetimeTrackPlay(track.toJson());

    if (state is LibraryLoaded) {
      final loadedState = state as LibraryLoaded;

      final newHistoryItem = HistoryModel(
        id: DateTime.now().millisecondsSinceEpoch,
        trackId: track.id,
        playedAt: DateTime.now().toIso8601String(),
        track: track,
      );

      final newHistory = _deduplicateHistory([newHistoryItem, ...loadedState.history]);
      _updateStateAndCache(loadedState.copyWith(history: newHistory));
    }
  }

  /// Retourne le Top [limit] des sons les plus écoutés selon une période (null: depuis toujours, 30: 30 jours, 7: 7 jours)
  List<WrappedTrackItem> getTopTracksForPeriod({int? days, int limit = 10}) {
    final Map<String, int> playCounts = {};
    final Map<String, TrackModel> trackMap = {};
    final now = DateTime.now();

    String normalizeKey(TrackModel t) {
      final cleanTitle = t.title.trim().toLowerCase();
      final cleanArtist = t.artistName.trim().toLowerCase();
      if (cleanTitle.isNotEmpty && cleanArtist.isNotEmpty) {
        return '${cleanTitle}__$cleanArtist';
      }
      return t.id;
    }

    // 1. Analyser l'historique de lecture
    if (state is LibraryLoaded) {
      final loaded = state as LibraryLoaded;
      for (final h in loaded.history) {
        if (h.track != null) {
          final dt = DateTime.tryParse(h.playedAt);
          if (days != null && dt != null) {
            if (now.difference(dt).inDays > days) continue;
          }
          final key = normalizeKey(h.track!);
          playCounts[key] = (playCounts[key] ?? 0) + 1;
          trackMap.putIfAbsent(key, () => h.track!);
        }
      }
    }

    // 2. Fusionner avec le compteur cumulatif local persistant
    final rawLocal = StorageService().getLifetimeTrackPlaysRaw();
    rawLocal.forEach((_, value) {
      if (value is Map && value['track'] is Map) {
        try {
          final track = TrackModel.fromJson(Map<String, dynamic>.from(value['track'] as Map));
          final key = normalizeKey(track);
          int localCount = 0;

          if (days != null) {
            final timestamps = value['play_timestamps'];
            if (timestamps is List && timestamps.isNotEmpty) {
              for (final ts in timestamps) {
                final dt = DateTime.tryParse(ts.toString());
                if (dt != null && now.difference(dt).inDays <= days) {
                  localCount++;
                }
              }
            } else {
              final lastPlayed = DateTime.tryParse((value['last_played_at'] ?? '').toString());
              if (lastPlayed != null && now.difference(lastPlayed).inDays <= days) {
                localCount = (value['count'] is int) ? value['count'] as int : 1;
              }
            }
          } else {
            localCount = (value['count'] is int) ? value['count'] as int : 1;
          }

          if (localCount > (playCounts[key] ?? 0)) {
            playCounts[key] = localCount;
          }
          trackMap.putIfAbsent(key, () => track);
        } catch (_) {}
      }
    });

    // 3. Si depuis toujours (days == null) et moins de sons que la limite, compléter avec favoris
    if (days == null && playCounts.length < limit && state is LibraryLoaded) {
      final loaded = state as LibraryLoaded;
      for (final fav in loaded.favorites) {
        final key = normalizeKey(fav);
        if (!playCounts.containsKey(key)) {
          playCounts[key] = 1;
          trackMap[key] = fav;
        }
        if (playCounts.length >= limit) break;
      }
    }

    final List<WrappedTrackItem> items = [];
    playCounts.forEach((key, count) {
      final track = trackMap[key];
      if (track != null && count > 0) {
        items.add(WrappedTrackItem(track: track, playCount: count));
      }
    });

    items.sort((a, b) => b.playCount.compareTo(a.playCount));
    if (items.length > limit) {
      return items.sublist(0, limit);
    }
    return items;
  }

  /// Retourne le Top [limit] des sons les plus écoutés depuis la création du compte
  List<WrappedTrackItem> getTopTracksSinceCreation({int limit = 10}) {
    return getTopTracksForPeriod(days: null, limit: limit);
  }
}
