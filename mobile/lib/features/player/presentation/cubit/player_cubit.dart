import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState, LoopMode;
import 'package:home_widget/home_widget.dart';
import '../../../../core/audio/audio_handler.dart';
import '../../../../core/storage/storage_service.dart';
import '../../data/models/lyrics_model.dart';
import '../../data/models/track_model.dart';
import '../../data/services/lyrics_service.dart';
import '../../../library/data/repositories/library_repository.dart';
import 'player_state.dart';

class PlayerCubit extends Cubit<PlayerState> {
  static bool get _supportsHomeWidget =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final SonoritizAudioHandler _audioHandler;
  final LyricsService _lyricsService = LyricsService();
  final Dio _metaDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
  ));
  final LibraryRepository? libraryRepository;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _resolvingSubscription;
  Timer? _sleepTimer;
  Timer? _prefetchTimer;
  Timer? _bufferingWatchdog;
  int? _nextShuffleIndex;
  String? _lastThirtySecPrefetchedForTrackId;
  bool _isResolving = false;
  bool _isPlayerLoading = false;
  int _consecutiveErrors = 0;

  // Historique léger des 5 derniers titres pour les widgets Android (Playlist & Récent)
  final List<_WidgetRecentEntry> _recentWidgetEntries = [];

  PlayerCubit({
    required SonoritizAudioHandler audioHandler,
    this.libraryRepository,
  })  : _audioHandler = audioHandler,
        super(PlayerState(isFreeLyricsMode: StorageService().isFreeLyricsMode)) {
    _initSubscriptions();

    _audioHandler.onToggleFavorite = (trackId) {
      _toggleFavoriteFromNotification();
    };
    _audioHandler.onToggleRepeat = () {
      toggleRepeat();
    };
    _audioHandler.onSkipToNext = () async {
      await playNext();
    };
    _audioHandler.onSkipToPrevious = () async {
      await playPrevious();
    };
    _audioHandler.onPlaybackError = (trackId, error) {
      if (state.currentTrack?.id == trackId) {
        debugPrint('[playback] failed track=$trackId: $error');
        _consecutiveErrors++;
        if (state.queue.length > 1 && _consecutiveErrors < 3) {
          debugPrint('[playback] skipping failed track to keep music alive ($_consecutiveErrors/3)');
          unawaited(playNext());
          return;
        }
        emit(state.copyWith(
          isBuffering: false,
          isPlaying: false,
          errorMessage: 'Impossible de lancer ce morceau. Vérifie ta connexion puis réessaie.',
        ));
        _syncWidgetPlaybackState(force: true);
      }
    };
  }

  int _lastWidgetSyncSecond = -1;

  String _formatWidgetDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    if (totalSeconds <= 0) return '0:00';
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> syncFromWidgetPreferences() async {
    if (!_supportsHomeWidget) return;
    try {
      final track = state.currentTrack;
      if (track == null) return;

      final widgetRepeat = await HomeWidget.getWidgetData<bool>('isRepeat');
      if (widgetRepeat != null) {
        final currentlyRepeating = state.loopMode != LoopMode.off;
        if (widgetRepeat != currentlyRepeating) {
          final nextMode = widgetRepeat ? LoopMode.all : LoopMode.off;
          emit(state.copyWith(loopMode: nextMode));
          await _audioHandler.setLoopMode(nextMode);
        }
      }

      if (libraryRepository != null) {
        final widgetFav = await HomeWidget.getWidgetData<bool>('isFavorite');
        if (widgetFav != null) {
          final realFav = await libraryRepository!.isFavorite(track.id);
          if (widgetFav != realFav) {
            if (widgetFav) {
              await libraryRepository!.addFavorite(track);
            } else {
              await libraryRepository!.removeFavorite(track.id);
            }
            await syncNotificationReactionState(track.id);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _syncWidgetPlaybackState({bool force = false}) async {
    if (!_supportsHomeWidget) return;
    final currentSec = state.position.inSeconds;
    if (!force && (currentSec - _lastWidgetSyncSecond).abs() < 30) {
      return;
    }
    _lastWidgetSyncSecond = currentSec;

    try {
      final totalMs = state.duration.inMilliseconds;
      final posMs = state.position.inMilliseconds;
      final int progress = totalMs > 0
          ? ((posMs * 1000) ~/ totalMs).clamp(0, 1000)
          : 0;

      await HomeWidget.saveWidgetData<bool>('isPlaying', state.isPlaying);
      await HomeWidget.saveWidgetData<bool>('isRepeat', state.loopMode != LoopMode.off);
      await HomeWidget.saveWidgetData<int>('progress', progress);
      await HomeWidget.saveWidgetData<String>('positionText', _formatWidgetDuration(state.position));
      await HomeWidget.saveWidgetData<String>('durationText', _formatWidgetDuration(state.duration));

      await HomeWidget.updateWidget(androidName: 'NowPlayingWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'PlaylistWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'MiniSquareWidgetProvider');
    } catch (_) {}
  }

  Future<void> syncNotificationReactionState([String? trackId]) async {
    final effectiveId = trackId ?? state.currentTrack?.id;
    if (effectiveId == null) return;
    final isFav = await libraryRepository?.isFavorite(effectiveId) ?? false;
    final isSuper = StorageService().getSuperlikesRaw().any((item) => item['id']?.toString() == effectiveId);
    _audioHandler.updateReactionState(isFavorite: isFav, isSuperliked: isSuper);
    if (!_supportsHomeWidget) return;
    try {
      await HomeWidget.saveWidgetData<bool>('isFavorite', isFav);
      await HomeWidget.saveWidgetData<bool>('isSuperliked', isSuper);
      await HomeWidget.updateWidget(androidName: 'NowPlayingWidgetProvider');
    } catch (_) {}
  }

  Future<void> _toggleFavoriteFromNotification() async {
    if (state.currentTrack != null && libraryRepository != null) {
      try {
        final trackId = state.currentTrack!.id;
        final isFav = await libraryRepository!.isFavorite(trackId);
        if (isFav) {
          await libraryRepository!.removeFavorite(trackId);
          if (_supportsHomeWidget) {
            await HomeWidget.saveWidgetData<bool>('isFavorite', false);
          }
        } else {
          await libraryRepository!.addFavorite(state.currentTrack!);
          if (_supportsHomeWidget) {
            await HomeWidget.saveWidgetData<bool>('isFavorite', true);
          }
        }
        if (_supportsHomeWidget) {
          await HomeWidget.updateWidget(androidName: 'NowPlayingWidgetProvider');
          await HomeWidget.updateWidget(androidName: 'PlaylistWidgetProvider');
        }
        await syncNotificationReactionState(trackId);
      } catch (e) {
        debugPrint('toggleFavorite from notification error: $e');
      }
    }
  }

  void _initSubscriptions() {
    _playerStateSubscription = _audioHandler.player.playerStateStream.listen((playerState) {
      final isCompleted = playerState.processingState == ProcessingState.completed;
      final prevPlaying = state.isPlaying;
      _isPlayerLoading = playerState.processingState == ProcessingState.buffering ||
          playerState.processingState == ProcessingState.loading;

      if (playerState.playing && playerState.processingState == ProcessingState.ready) {
        _consecutiveErrors = 0;
      }

      final buffering = _isResolving || _isPlayerLoading;
      _checkBufferingWatchdog(buffering, playerState.playing);
      emit(state.copyWith(
        isPlaying: _isResolving ? true : playerState.playing,
        isBuffering: buffering,
      ));

      if (prevPlaying != playerState.playing) {
        if (playerState.playing) {
          debugPrint('[playback] player entered playing state for ${state.currentTrack?.id}');
        }
        _syncWidgetPlaybackState(force: true);
      }

      if (isCompleted && !_isResolving) {
        _handleTrackCompleted();
      }
    });

    _resolvingSubscription = _audioHandler.resolvingStream.listen((resolving) {
      _isResolving = resolving;
      final buffering = _isResolving || _isPlayerLoading;
      _checkBufferingWatchdog(buffering, _audioHandler.player.playing);
      emit(state.copyWith(isBuffering: buffering));
    });

    _positionSubscription = _audioHandler.player.positionStream.listen((pos) {
      if (_isResolving) return;
      if ((pos - state.position).inMilliseconds.abs() < 1000) return;
      emit(state.copyWith(position: pos));

      // Pré-chargement « Zero-Latency » à ~30s de la fin du morceau (synchronisé avec la bannière « À suivre »)
      final totalSec = state.duration.inSeconds;
      final remainingSec = totalSec - pos.inSeconds;
      final currentId = state.currentTrack?.id;
      if (currentId != null &&
          totalSec >= 40 &&
          remainingSec <= 32 &&
          remainingSec >= 22 &&
          _lastThirtySecPrefetchedForTrackId != currentId) {
        _lastThirtySecPrefetchedForTrackId = currentId;
        _triggerNextTrackZeroLatencyPrefetch();
      }
    });

    _durationSubscription = _audioHandler.player.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        emit(state.copyWith(duration: dur));
        _syncWidgetPlaybackState(force: true);
      }
    });
  }

  void _handleTrackCompleted() {
    if (state.loopMode == LoopMode.one) {
      _audioHandler.seek(Duration.zero);
      _audioHandler.play();
    } else {
      if (state.currentIndex < state.queue.length - 1) {
        playNext();
      } else {
        if (state.loopMode == LoopMode.all) {
          playNext();
        } else {
          _audioHandler.pause();
          _audioHandler.seek(Duration.zero);
          emit(state.copyWith(isPlaying: false));
          _syncWidgetPlaybackState(force: true);
        }
      }
    }
  }

  String _toLightweightWidgetCoverUrl(String url) {
    if (url.isEmpty) return '';
    return url
        .replaceAll('1000x1000bb.jpg', '300x300bb.jpg')
        .replaceAll('1000x1000', '250x250')
        .replaceAll('500x500', '250x250');
  }

  Future<String?> _resolveWidgetCoverPath(TrackModel track) async {
    try {
      // 1. Pochette hors-ligne déjà téléchargée
      final offline = _audioHandler.offlineRepository?.getOfflineTrack(track.id);
      if (offline != null &&
          offline.localCoverPath.isNotEmpty &&
          await File(offline.localCoverPath).exists()) {
        return offline.localCoverPath;
      }

      // 2. Fichier local sur l'appareil
      if (track.coverUrl.startsWith('file://')) {
        final localPath = track.coverUrl.replaceFirst('file://', '');
        if (await File(localPath).exists()) {
          return localPath;
        }
        return null;
      }

      if (track.coverUrl.isEmpty) return null;

      // 3. Miniature légère dédiée aux widgets (300x300 max)
      final tempDir = await getTemporaryDirectory();
      final safeId = track.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final localPath = '${tempDir.path}/widget_thumb_$safeId.jpg';
      final file = File(localPath);
      if (!await file.exists() || await file.length() < 512) {
        final thumbUrl = _toLightweightWidgetCoverUrl(track.coverUrl);
        await _metaDio.download(thumbUrl, localPath);
      }
      if (await file.exists()) {
        return localPath;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _resolveWidgetArtistAvatarPath(String artistName) async {
    try {
      final clean = artistName.split(RegExp(r'(\s+(?:feat\.?|ft\.?|featuring|and|&|x|\/)\s+|,\s+|\s*;\s*)', caseSensitive: false)).first.trim();
      final target = clean.isNotEmpty ? clean : artistName.trim();
      if (target.isEmpty || target.toLowerCase() == 'artiste inconnu') return null;

      final tempDir = await getTemporaryDirectory();
      final safeName = target.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final localPath = '${tempDir.path}/widget_artist_$safeName.jpg';
      final file = File(localPath);
      if (await file.exists() && await file.length() > 512) {
        return localPath;
      }

      final response = await _metaDio.get(
        'https://api.deezer.com/search/artist?q=${Uri.encodeComponent(target)}&limit=3',
      );
      if (response.statusCode == 200 &&
          response.data is Map &&
          response.data['data'] is List &&
          (response.data['data'] as List).isNotEmpty) {
        final List dataList = response.data['data'] as List;
        final match = dataList.first as Map<String, dynamic>?;
        final rawPic = (match?['picture_medium'] ?? match?['picture_small'] ?? match?['picture'] ?? '').toString();
        if (rawPic.isNotEmpty && !rawPic.contains('/images/artist//')) {
          await _metaDio.download(rawPic, localPath);
          if (await file.exists()) {
            return localPath;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _updateHomeWidget(TrackModel track) async {
    if (!_supportsHomeWidget) return;
    try {
      await HomeWidget.saveWidgetData<String>('title', track.title);
      await HomeWidget.saveWidgetData<String>('artist', track.artistName);
      await HomeWidget.saveWidgetData<bool>('isPlaying', state.isPlaying);
      await HomeWidget.saveWidgetData<bool>('isRepeat', state.loopMode != LoopMode.off);

      final totalMs = state.duration.inMilliseconds;
      final posMs = state.position.inMilliseconds;
      final int progress = totalMs > 0
          ? ((posMs * 1000) ~/ totalMs).clamp(0, 1000)
          : 0;
      await HomeWidget.saveWidgetData<int>('progress', progress);
      await HomeWidget.saveWidgetData<String>('positionText', _formatWidgetDuration(state.position));
      await HomeWidget.saveWidgetData<String>(
        'durationText',
        _formatWidgetDuration(
          state.duration.inSeconds > 0
              ? state.duration
              : Duration(seconds: track.durationSeconds),
        ),
      );

      final isFav = await libraryRepository?.isFavorite(track.id) ?? false;
      await HomeWidget.saveWidgetData<bool>('isFavorite', isFav);

      final isSuper = StorageService().getSuperlikesRaw().any((item) => item['id']?.toString() == track.id);
      await HomeWidget.saveWidgetData<bool>('isSuperliked', isSuper);

      final coverPath = await _resolveWidgetCoverPath(track);
      await HomeWidget.saveWidgetData<String>('coverPath', coverPath);

      final artistAvatarPath = await _resolveWidgetArtistAvatarPath(track.artistName);
      await HomeWidget.saveWidgetData<String>('artistAvatarPath', artistAvatarPath);

      // Mettre à jour l'historique des 5 derniers morceaux pour PlaylistWidget & RecentListWidget
      _recentWidgetEntries.removeWhere((e) => e.id == track.id);
      _recentWidgetEntries.insert(
        0,
        _WidgetRecentEntry(
          id: track.id,
          title: track.title,
          artist: track.artistName,
          coverPath: coverPath,
        ),
      );
      if (_recentWidgetEntries.length > 5) {
        _recentWidgetEntries.removeRange(5, _recentWidgetEntries.length);
      }

      for (int i = 0; i < 5; i++) {
        if (i < _recentWidgetEntries.length) {
          final entry = _recentWidgetEntries[i];
          await HomeWidget.saveWidgetData<String>('hist_title_$i', entry.title);
          await HomeWidget.saveWidgetData<String>('hist_artist_$i', entry.artist);
          await HomeWidget.saveWidgetData<String>('hist_cover_$i', entry.coverPath);
        } else {
          await HomeWidget.saveWidgetData<String>('hist_title_$i', null);
          await HomeWidget.saveWidgetData<String>('hist_artist_$i', null);
          await HomeWidget.saveWidgetData<String>('hist_cover_$i', null);
        }
      }

      await HomeWidget.updateWidget(androidName: 'NowPlayingWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'PlaylistWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'MiniSquareWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'RecentListWidgetProvider');
    } catch (_) {}
  }

  String _resolvePlaybackSource(TrackModel track, String? explicitSource) {
    if (explicitSource != null && explicitSource.trim().isNotEmpty) {
      return explicitSource.trim();
    }
    if (track.id.startsWith('local_') || track.albumName == 'Local Audio') {
      return 'Fichiers locaux';
    }
    if (track.genre.toLowerCase().contains('download') ||
        (track.audioUrl.isNotEmpty && !track.audioUrl.startsWith('http'))) {
      return 'Téléchargements';
    }
    if ((track.genre == 'Album Studio' || track.genre == 'Deezer Album') &&
        track.albumName.isNotEmpty) {
      return "l'album ${track.albumName}";
    }
    if (track.genre == 'Top Titres' || track.genre == 'Deezer Top') {
      return "le profil de ${track.artistName.split(' feat.').first}";
    }
    if (track.albumName.isNotEmpty &&
        track.albumName != 'YouTube Audio' &&
        track.albumName != 'Unknown Album') {
      return "l'album ${track.albumName}";
    }
    return 'Sonoritiz Mix';
  }

  Future<void> playTrack(
    TrackModel track, {
    List<TrackModel>? queue,
    String? source,
  }) async {
    final currentQueue = queue ?? [track];
    final index = currentQueue.indexWhere((t) => t.id == track.id);
    final targetIndex = index >= 0 ? index : 0;
    final resolvedSource = _resolvePlaybackSource(track, source);

    _consecutiveErrors = 0;
    _isResolving = true;
    emit(state.copyWith(
      queue: currentQueue,
      currentIndex: targetIndex,
      duration: Duration(seconds: track.durationSeconds),
      position: Duration.zero,
      playbackSource: resolvedSource,
      isBuffering: true,
      isPlaying: true,
      clearError: true,
    ));

    libraryRepository?.addToHistory(track);
    await _startTrack(track);
  }

  static final Map<String, String> _resolvedFeatCache = <String, String>{};
  static final Set<String> _inFlightEnrichIds = <String>{};

  Future<void> _startTrack(TrackModel track) async {
    _prefetchTimer?.cancel();
    StorageService().recordLifetimeTrackPlay(track.toJson());

    // Résolution immédiate (0s de délai) des featurings (contributors) et de la pochette HD en parallèle
    unawaited(_fetchHighResCover(track));
    unawaited(_enrichUpcomingQueueMetadata());

    await _audioHandler.playTrack(track.toMediaItem());
    unawaited(syncNotificationReactionState(track.id));
    _fetchLyrics(track);

    // Mise à jour rapide des métadonnées et de la miniature du widget
    Future.delayed(const Duration(seconds: 2), () {
      if (!isClosed && state.currentTrack?.id == track.id) {
        final latestTrack = state.currentTrack ?? track;
        _updateHomeWidget(latestTrack);
      }
    });
    _schedulePrefetchOfNext(track);
  }

  /// Enrichit en arrière-plan les prochains titres de la file d'attente pour que leurs featurings
  /// soient déjà affichés dans la file et dans la bannière « À suivre ».
  Future<void> _enrichUpcomingQueueMetadata() async {
    if (isClosed || state.queue.length < 2) return;
    final List<TrackModel> candidates = [];
    final next = peekNextTrack;
    if (next != null) candidates.add(next);
    for (int offset = 1; offset <= 3; offset++) {
      final idx = state.currentIndex + offset;
      if (idx >= 0 && idx < state.queue.length) {
        final t = state.queue[idx];
        if (!candidates.any((c) => c.id == t.id)) {
          candidates.add(t);
        }
      }
    }
    for (final candidate in candidates.take(3)) {
      if (isClosed) return;
      await _fetchHighResCover(candidate);
    }
  }

  /// Retourne le prochain morceau qui sera réellement joué (prend en compte le mode aléatoire et LoopMode).
  TrackModel? get peekNextTrack {
    if (state.loopMode == LoopMode.one || state.queue.isEmpty) return null;
    if (state.isShuffleModeEnabled && state.queue.length > 1) {
      if (_nextShuffleIndex == null ||
          _nextShuffleIndex! < 0 ||
          _nextShuffleIndex! >= state.queue.length ||
          _nextShuffleIndex == state.currentIndex) {
        int candidate = state.currentIndex;
        while (candidate == state.currentIndex) {
          candidate = Random().nextInt(state.queue.length);
        }
        _nextShuffleIndex = candidate;
      }
      return state.queue[_nextShuffleIndex!];
    }
    if (state.currentIndex + 1 < state.queue.length) {
      return state.queue[state.currentIndex + 1];
    }
    if (state.loopMode == LoopMode.all && state.queue.length > 1) {
      return state.queue.first;
    }
    return null;
  }

  void _triggerNextTrackZeroLatencyPrefetch() {
    final next = peekNextTrack;
    if (next == null) return;
    unawaited(_audioHandler.prefetch(next.toMediaItem()));
    unawaited(_fetchHighResCover(next));
  }

  void _schedulePrefetchOfNext(TrackModel current) {
    if (state.currentTrack?.id != current.id) return;
    _prefetchTimer?.cancel();
    if (state.queue.length < 2) return;

    _prefetchTimer = Timer(const Duration(seconds: 20), () {
      if (isClosed || state.currentTrack?.id != current.id) return;
      _triggerNextTrackZeroLatencyPrefetch();
    });
  }

  bool _hasMultipleArtists(String artistName) {
    return RegExp(
      r'(\bfeat\.?|\bft\.?|\bfeaturing\b|&|,|\bx\b)',
      caseSensitive: false,
    ).hasMatch(artistName);
  }

  String _extractFeatFromTitleIfAny(String currentArtist, String title) {
    if (_hasMultipleArtists(currentArtist)) return currentArtist;
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
      if (featRaw.isNotEmpty &&
          !currentArtist.toLowerCase().contains(featRaw.toLowerCase())) {
        return '$currentArtist feat. $featRaw';
      }
    }
    return currentArtist;
  }

  String? _formatContributorsList(List contributorsRaw) {
    final List<String> contributors = [];
    for (final c in contributorsRaw) {
      if (c is Map && c['name'] != null) {
        final name = c['name'].toString().trim();
        if (name.isNotEmpty &&
            !contributors.any((a) => a.toLowerCase() == name.toLowerCase())) {
          contributors.add(name);
        }
      }
    }
    if (contributors.length > 1) {
      return '${contributors.first} feat. ${contributors.sublist(1).join(', ')}';
    }
    return null;
  }

  Future<void> _fetchHighResCover(TrackModel track) async {
    if (track.id.startsWith('local_') ||
        track.id.startsWith('deezer_podcast_') ||
        track.id.startsWith('deezer_book_')) {
      return;
    }
    if (_inFlightEnrichIds.contains(track.id)) return;
    _inFlightEnrichIds.add(track.id);

    try {
      final offline = _audioHandler.offlineRepository?.getOfflineTrack(track.id);
      final bool hasOfflineCover =
          (offline != null && offline.localCoverPath.isNotEmpty) ||
              track.coverUrl.startsWith('file://');

      String newCoverUrl = track.coverUrl;
      String newArtistName =
          _extractFeatFromTitleIfAny(track.artistName, track.title);

      // 0. Vérifier le cache mémoire des featurings déjà résolus
      final cachedArtist = _resolvedFeatCache[track.id];
      if (cachedArtist != null && cachedArtist.isNotEmpty) {
        newArtistName = cachedArtist;
      }

      // 1. Récupération officielle des `contributors` via l'API Deezer
      if (!_hasMultipleArtists(newArtistName)) {
        try {
          String? deezerId;
          if (track.id.startsWith('deezer_')) {
            deezerId = track.id.replaceFirst('deezer_', '').trim();
          } else {
            // Pour les sons YouTube / externes : rechercher le titre exact sur Deezer
            final cleanQuery = '${track.artistName} ${track.title}'.trim();
            final searchRes = await _metaDio.get(
              'https://api.deezer.com/search/track?q=${Uri.encodeComponent(cleanQuery)}&limit=3',
            );
            if (searchRes.statusCode == 200 &&
                searchRes.data is Map &&
                searchRes.data['data'] is List &&
                (searchRes.data['data'] as List).isNotEmpty) {
              final List results = searchRes.data['data'] as List;
              final String targetArtist = track.artistName.toLowerCase().trim();
              for (final item in results) {
                if (item is Map) {
                  final itemArtist =
                      (item['artist']?['name'] ?? '').toString().toLowerCase();
                  if (itemArtist.contains(targetArtist) ||
                      targetArtist.contains(itemArtist)) {
                    deezerId = item['id']?.toString();
                    break;
                  }
                }
              }
              deezerId ??= results.first['id']?.toString();
            }
          }

          if (deezerId != null && deezerId.isNotEmpty) {
            final dzRes =
                await _metaDio.get('https://api.deezer.com/track/$deezerId');
            if (dzRes.statusCode == 200 && dzRes.data is Map) {
              final dzData = dzRes.data as Map<String, dynamic>;
              if (dzData['contributors'] is List) {
                final formatted =
                    _formatContributorsList(dzData['contributors'] as List);
                if (formatted != null) {
                  newArtistName = formatted;
                }
              }
              if (!hasOfflineCover &&
                  (newCoverUrl.isEmpty ||
                      newCoverUrl.contains('ytimg.com') ||
                      newCoverUrl.contains('250x250'))) {
                final dzCover = (dzData['album']?['cover_xl'] ??
                        dzData['album']?['cover_big'] ??
                        '')
                    .toString();
                if (dzCover.isNotEmpty) {
                  newCoverUrl = dzCover;
                }
              }
            }
          }
        } catch (_) {}
      }

      // 2. Enrichissement iTunes (pochette 600x600 + fallback featuring dans artistName ET trackName)
      final bool needsCoverUpgrade =
          !hasOfflineCover && !newCoverUrl.contains('mzstatic.com');
      final bool needsFeatCheck = !_hasMultipleArtists(newArtistName);

      if (needsCoverUpgrade || needsFeatCheck) {
        try {
          final url =
              'https://itunes.apple.com/search?term=${Uri.encodeComponent('${track.artistName} ${track.title}')}&entity=song&limit=2';
          final response = await _metaDio.get(url);
          if (response.statusCode == 200) {
            final data = response.data;
            if (data is Map && (data['resultCount'] ?? 0) > 0) {
              final firstResult = data['results'][0];
              if (needsCoverUpgrade) {
                final artworkUrl = firstResult['artworkUrl100'] as String?;
                if (artworkUrl != null && artworkUrl.isNotEmpty) {
                  newCoverUrl =
                      artworkUrl.replaceAll('100x100bb.jpg', '600x600bb.jpg');
                }
              }
              if (!_hasMultipleArtists(newArtistName)) {
                final itunesArtist =
                    (firstResult['artistName'] ?? '').toString().trim();
                final itunesTrackName =
                    (firstResult['trackName'] ?? '').toString().trim();

                if (_hasMultipleArtists(itunesArtist)) {
                  final baseMain = track.artistName
                      .split(RegExp(r'\s+|\,'))
                      .first
                      .toLowerCase();
                  if (itunesArtist.toLowerCase().contains(baseMain)) {
                    // Normaliser "Artiste 1 & Artiste 2" en "Artiste 1 feat. Artiste 2" si souhaité
                    newArtistName = itunesArtist;
                  }
                }
                if (!_hasMultipleArtists(newArtistName) &&
                    itunesTrackName.isNotEmpty) {
                  newArtistName = _extractFeatFromTitleIfAny(
                    newArtistName,
                    itunesTrackName,
                  );
                }
              }
            }
          }
        } catch (_) {}
      }

      if (_hasMultipleArtists(newArtistName)) {
        if (_resolvedFeatCache.length >= 150) {
          _resolvedFeatCache.remove(_resolvedFeatCache.keys.first);
        }
        _resolvedFeatCache[track.id] = newArtistName;
      }

      if (isClosed) return;
      if (newCoverUrl != track.coverUrl || newArtistName != track.artistName) {
        final updatedTrack = track.copyWith(
          coverUrl: newCoverUrl,
          artistName: newArtistName,
        );

        final index = state.queue.indexWhere((t) => t.id == track.id);
        if (index != -1) {
          final updatedQueue = List<TrackModel>.from(state.queue);
          updatedQueue[index] = updatedTrack;
          emit(state.copyWith(queue: updatedQueue));

          if (state.currentIndex == index) {
            _updateHomeWidget(updatedTrack);
            _audioHandler.mediaItem.add(updatedTrack.toMediaItem());
            if (newArtistName != track.artistName) {
              libraryRepository?.addToHistory(updatedTrack);
            }
          }
        }
      }
    } finally {
      _inFlightEnrichIds.remove(track.id);
    }
  }

  Future<void> _fetchLyrics(TrackModel track) async {
    emit(state.copyWith(currentLyrics: LyricsModel(plainLyrics: '', syncedLyrics: '')));
    try {
      final lyrics = await _lyricsService.getLyrics(track.id, track.artistName, track.title, track.durationSeconds);
      if (!isClosed && state.currentTrack?.id == track.id) {
        emit(state.copyWith(currentLyrics: lyrics));
      }
    } catch (_) {}
  }

  void toggleFreeLyricsMode() {
    final newValue = !state.isFreeLyricsMode;
    StorageService().setFreeLyricsMode(newValue);
    emit(state.copyWith(isFreeLyricsMode: newValue));
  }

  Future<void> setVocalAttenuation(double level) async {
    final clamped = level.clamp(0.0, 1.0);
    emit(state.copyWith(vocalAttenuationLevel: clamped));
    await _audioHandler.setVocalAttenuation(clamped);
  }

  Future<void> resetVocalAttenuation() async {
    await setVocalAttenuation(0.0);
  }

  Future<void> applyAudioSettings({bool clearResolvedStreams = false}) async {
    await _audioHandler.applyUserAudioSettings(
      clearResolvedStreams: clearResolvedStreams,
    );
  }

  Future<void> togglePlayPause() async {
    if (!state.hasTrack) return;
    if (state.errorMessage != null) {
      await retryCurrentTrack();
      return;
    }
    if (state.isPlaying && !_isResolving) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> retryCurrentTrack() async {
    final track = state.currentTrack;
    if (track == null) return;
    _consecutiveErrors = 0;
    emit(state.copyWith(
      isBuffering: true,
      isPlaying: true,
      clearError: true,
    ));
    await _startTrack(track);
  }

  Future<void> pause() async {
    if (state.isPlaying) {
      await _audioHandler.pause();
    }
  }

  /// Réinitialise complètement la file d'attente et la lecture lors d'une déconnexion.
  Future<void> resetForLogout() async {
    _consecutiveErrors = 0;
    _nextShuffleIndex = null;
    try {
      await _audioHandler.stop();
    } catch (_) {
      await pause();
    }
    emit(const PlayerState());
  }

  Future<void> play() async {
    if (!state.isPlaying) {
      await _audioHandler.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
    emit(state.copyWith(position: position));
    _syncWidgetPlaybackState(force: true);
  }

  Future<void> playNext() async {
    if (state.queue.isEmpty) return;
    int nextIndex;
    if (state.isShuffleModeEnabled && state.queue.length > 1) {
      if (_nextShuffleIndex != null && _nextShuffleIndex! < state.queue.length) {
        nextIndex = _nextShuffleIndex!;
        _nextShuffleIndex = null;
      } else {
        nextIndex = state.currentIndex;
        while (nextIndex == state.currentIndex) {
          nextIndex = Random().nextInt(state.queue.length);
        }
      }
    } else {
      nextIndex = (state.currentIndex + 1) % state.queue.length;
    }
    final nextTrack = state.queue[nextIndex];
    emit(state.copyWith(
      currentIndex: nextIndex,
      duration: Duration(seconds: nextTrack.durationSeconds),
      position: Duration.zero,
      isBuffering: true,
      isPlaying: true,
      clearError: true,
    ));
    libraryRepository?.addToHistory(nextTrack);
    await _startTrack(nextTrack);
  }

  Future<void> playPrevious() async {
    if (state.queue.isEmpty) return;
    if (state.position > const Duration(seconds: 5)) {
      await seek(Duration.zero);
      return;
    }
    int prevIndex;
    if (state.isShuffleModeEnabled && state.queue.length > 1) {
      prevIndex = state.currentIndex;
      while (prevIndex == state.currentIndex) {
        prevIndex = Random().nextInt(state.queue.length);
      }
    } else {
      prevIndex = (state.currentIndex - 1 + state.queue.length) % state.queue.length;
    }
    final prevTrack = state.queue[prevIndex];
    emit(state.copyWith(
      currentIndex: prevIndex,
      duration: Duration(seconds: prevTrack.durationSeconds),
      position: Duration.zero,
      isBuffering: true,
      isPlaying: true,
      clearError: true,
    ));
    libraryRepository?.addToHistory(prevTrack);
    await _startTrack(prevTrack);
  }

  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= state.queue.length || index == state.currentIndex) return;
    final targetTrack = state.queue[index];
    _consecutiveErrors = 0;
    emit(state.copyWith(
      currentIndex: index,
      duration: Duration(seconds: targetTrack.durationSeconds),
      position: Duration.zero,
      isBuffering: true,
      isPlaying: true,
      clearError: true,
    ));
    libraryRepository?.addToHistory(targetTrack);
    await _startTrack(targetTrack);
  }

  void addToQueue(TrackModel track) {
    final updatedQueue = List<TrackModel>.from(state.queue)..add(track);
    emit(state.copyWith(queue: updatedQueue));
    if (state.currentTrack != null) {
      _schedulePrefetchOfNext(state.currentTrack!);
    }
  }

  void reorderQueue(int oldIndex, int newIndex) {
    final updatedQueue = List<TrackModel>.from(state.queue);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = updatedQueue.removeAt(oldIndex);
    updatedQueue.insert(newIndex, item);

    int newCurrentIndex = state.currentIndex;
    if (oldIndex == state.currentIndex) {
      newCurrentIndex = newIndex;
    } else if (oldIndex < state.currentIndex && newIndex >= state.currentIndex) {
      newCurrentIndex--;
    } else if (oldIndex > state.currentIndex && newIndex <= state.currentIndex) {
      newCurrentIndex++;
    }

    _nextShuffleIndex = null;
    emit(state.copyWith(queue: updatedQueue, currentIndex: newCurrentIndex));
    if (state.currentTrack != null) {
      _schedulePrefetchOfNext(state.currentTrack!);
    }
  }

  Future<void> toggleShuffle() async {
    final newShuffleMode = !state.isShuffleModeEnabled;
    emit(state.copyWith(isShuffleModeEnabled: newShuffleMode));
    await _audioHandler.setShuffleModeEnabled(newShuffleMode);

    _nextShuffleIndex = null;
    if (state.currentTrack != null) {
      _schedulePrefetchOfNext(state.currentTrack!);
    }
  }

  Future<void> toggleRepeat() async {
    LoopMode nextMode;
    switch (state.loopMode) {
      case LoopMode.off:
        nextMode = LoopMode.all;
        break;
      case LoopMode.all:
        nextMode = LoopMode.one;
        break;
      case LoopMode.one:
        nextMode = LoopMode.off;
        break;
    }
    emit(state.copyWith(loopMode: nextMode));
    await _audioHandler.setLoopMode(nextMode);
    _syncWidgetPlaybackState(force: true);
  }

  void _checkBufferingWatchdog(bool isBuffering, bool playerIsPlaying) {
    _bufferingWatchdog?.cancel();
    if (isBuffering && !_isResolving && playerIsPlaying) {
      _bufferingWatchdog = Timer(const Duration(seconds: 15), () {
        if (!isClosed && state.isBuffering && _audioHandler.player.playing) {
          final trackId = state.currentTrack?.id;
          if (trackId != null) {
            unawaited(_audioHandler.reportPlaybackStall(trackId));
          } else {
            emit(state.copyWith(isBuffering: false));
          }
        }
      });
    }
  }

  @override
  Future<void> close() {
    _bufferingWatchdog?.cancel();
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _resolvingSubscription?.cancel();
    _prefetchTimer?.cancel();
    _sleepTimer?.cancel();
    return super.close();
  }

  void startSleepTimer(Duration duration) {
    cancelSleepTimer();
    emit(state.copyWith(
      isSleepTimerActive: true,
      sleepTimerRemaining: duration,
    ));

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.sleepTimerRemaining == null) return;

      final remaining = state.sleepTimerRemaining! - const Duration(seconds: 1);

      if (remaining.inSeconds <= 0) {
        cancelSleepTimer();
        _audioHandler.pause();
      } else {
        emit(state.copyWith(sleepTimerRemaining: remaining));
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    emit(state.copyWith(
      isSleepTimerActive: false,
      sleepTimerRemaining: Duration.zero,
    ));
  }
}

class _WidgetRecentEntry {
  final String id;
  final String title;
  final String artist;
  final String? coverPath;

  const _WidgetRecentEntry({
    required this.id,
    required this.title,
    required this.artist,
    this.coverPath,
  });
}
