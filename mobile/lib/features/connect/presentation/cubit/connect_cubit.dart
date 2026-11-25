import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../library/data/repositories/library_repository.dart'
    show PlaylistModel;
import '../../../player/data/models/track_model.dart';
import '../../../player/presentation/cubit/player_cubit.dart';
import '../../../player/presentation/cubit/player_state.dart';
import '../../data/repositories/connect_repository.dart';
import '../../data/services/connect_websocket_service.dart';
import 'connect_state.dart';

class ConnectCubit extends Cubit<ConnectState> {
  final StorageService storageService;
  final ConnectRepository repository;
  final PlayerCubit playerCubit;
  final ConnectWebSocketService webSocketService = ConnectWebSocketService();

  StreamSubscription? _wsSubscription;
  StreamSubscription<PlayerState>? _playerSubscription;
  Timer? _syncTimer;
  Timer? _httpSyncTimer;
  Timer? _hostPublishDebounce;

  PlayerState? _lastPlayerState;
  bool _httpSyncHealthy = false;
  bool _isSyncInFlight = false;
  bool _pendingUrgentHostSync = false;

  int _hostSeq = 1;
  int _lastAppliedRemoteSeq = -1;
  String _sharedPlaylistTitle = 'File du salon';

  String? _cachedMyAvatarPayload;
  String? _lastAvatarSourcePath;

  ConnectCubit({
    required this.storageService,
    required this.repository,
    required this.playerCubit,
  }) : super(ConnectInitial());

  /// Résout la photo de profil de l'utilisateur courant :
  /// 1. Miniature 72x72 (`data:image/png;base64,...`) depuis sa galerie locale,
  /// 2. Sinon URL http/https directe,
  /// 3. Sinon photo de son 1er artiste suivi/consulté.
  Future<String> _resolveMyAvatarPayload() async {
    try {
      final rawPath = (storageService.getProfileImagePath() ?? '').trim();
      if (rawPath.isNotEmpty &&
          rawPath == _lastAvatarSourcePath &&
          _cachedMyAvatarPayload != null &&
          _cachedMyAvatarPayload!.isNotEmpty) {
        return _cachedMyAvatarPayload!;
      }

      if (rawPath.startsWith('http://') ||
          rawPath.startsWith('https://') ||
          rawPath.startsWith('data:image/')) {
        _lastAvatarSourcePath = rawPath;
        _cachedMyAvatarPayload = rawPath;
        return rawPath;
      }

      if (!kIsWeb && rawPath.isNotEmpty) {
        final cleanPath = rawPath.replaceFirst('file://', '');
        final file = File(cleanPath);
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          final codec = await ui.instantiateImageCodec(
            bytes,
            targetWidth: 72,
            targetHeight: 72,
          );
          final frame = await codec.getNextFrame();
          final byteData = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (byteData != null) {
            final thumbBytes = byteData.buffer.asUint8List();
            final dataUri =
                'data:image/png;base64,${base64Encode(thumbBytes)}';
            if (dataUri.length <= 155000) {
              _lastAvatarSourcePath = rawPath;
              _cachedMyAvatarPayload = dataUri;
              return dataUri;
            }
          }
        }
      }

      final topArtists = storageService.getTopSearchedArtists(limit: 5);
      for (final a in topArtists) {
        final img = (a['image'] ?? '').toString().trim();
        if (img.startsWith('http://') || img.startsWith('https://')) {
          return img;
        }
      }
    } catch (_) {}
    return '';
  }

  List<Map<String, dynamic>> _participantsFrom(
    dynamic raw, {
    int? hostUserId,
  }) {
    if (raw is! List) return const [];
    final myUsername = storageService.username.trim().toLowerCase();
    final myLocalPhoto = (storageService.getProfileImagePath() ?? '').trim();

    return raw.whereType<Map>().map((participant) {
      final user = participant['user'];
      int? uid;
      String username = 'Auditeur';
      String avatar = (participant['avatar'] ?? '').toString().trim();
      final bool isHostFlag = participant['is_host'] == true;

      if (user is Map) {
        uid = user['id'] is int
            ? user['id'] as int
            : int.tryParse((user['id'] ?? '').toString());
        username = (user['username'] ?? 'Auditeur').toString();
        if (avatar.isEmpty) {
          avatar = (user['avatar'] ?? '').toString().trim();
        }
      } else {
        uid = participant['id'] is int
            ? participant['id'] as int
            : int.tryParse((participant['id'] ?? '').toString());
        username = (participant['username'] ?? 'Auditeur').toString();
      }

      if (avatar.isEmpty &&
          myLocalPhoto.isNotEmpty &&
          myUsername.isNotEmpty &&
          username.trim().toLowerCase() == myUsername) {
        avatar = myLocalPhoto;
      }

      return <String, dynamic>{
        'id': uid,
        'username': username,
        'avatar': avatar,
        'is_host': isHostFlag || (hostUserId != null && uid == hostUserId),
        'status': 'connected',
      };
    }).toList();
  }

  List<Map<String, dynamic>> _mapListFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<TrackModel> _tracksFromRaw(dynamic raw) {
    if (raw is! List) return const [];
    final List<TrackModel> parsed = [];
    for (final item in raw) {
      if (item is Map) {
        try {
          final map = Map<String, dynamic>.from(item);
          final ytVid = (map['youtube_video_id'] ?? '').toString().trim();
          final track = TrackModel.fromJson(map);
          if (ytVid.isNotEmpty) {
            playerCubit.seedResolvedVideoId(track.id, ytVid);
          }
          parsed.add(track);
        } catch (_) {}
      }
    }
    return parsed;
  }

  int? _extractHostUserId(Map<String, dynamic> data) {
    final hostUser = data['host_user'];
    if (hostUser is Map && hostUser['id'] != null) {
      return hostUser['id'] is int
          ? hostUser['id'] as int
          : int.tryParse(hostUser['id'].toString());
    }
    return null;
  }

  List<TrackModel> _extractHostWindowQueue(PlayerState pState) {
    final full = pState.queue;
    if (full.isEmpty) {
      return pState.currentTrack != null ? [pState.currentTrack!] : const [];
    }
    if (full.length <= 30) return List<TrackModel>.from(full);
    final int start = (pState.currentIndex - 4).clamp(0, full.length - 30);
    return full.sublist(start, start + 30);
  }

  Map<String, dynamic> _shareableTrack(TrackModel track) {
    final resolvedVid = playerCubit.getResolvedVideoId(track.id);
    return <String, dynamic>{
      'id': track.id,
      'title': track.title,
      'artist_name': track.artistName,
      'album_name': track.albumName,
      'cover_url': track.coverUrl,
      'duration_seconds': track.durationSeconds,
      'genre': track.genre,
      'license_ccurl': track.licenseCcUrl,
      if (resolvedVid != null && resolvedVid.isNotEmpty)
        'youtube_video_id': resolvedVid,
    };
  }

  Future<void> createSession() async {
    emit(ConnectLoading());
    try {
      final avatar = await _resolveMyAvatarPayload();
      final pState = playerCubit.state;
      final currentTrack = pState.currentTrack;
      final initialQueue = _extractHostWindowQueue(pState);
      final sourceLabel = pState.playbackSource.trim();
      _sharedPlaylistTitle = (sourceLabel.isNotEmpty &&
              sourceLabel != 'Reprise d’écoute' &&
              sourceLabel != 'Sonoritiz Mix')
          ? sourceLabel
          : 'File du salon';
      _hostSeq = 1;
      _lastAppliedRemoteSeq = -1;

      final data = await repository.createSession(
        avatar: avatar,
        initialTrack:
            currentTrack != null ? _shareableTrack(currentTrack) : null,
        position: pState.position.inMilliseconds / 1000.0,
        isPlaying: pState.isPlaying,
        isBuffering: pState.isBuffering,
        sharedPlaylistTitle: _sharedPlaylistTitle,
        sharedQueue: initialQueue.map(_shareableTrack).toList(),
      );
      final int sessionId = data['id'] as int;
      final String inviteCode = (data['invite_code'] ?? '').toString();
      final int maxParticipants =
          data['max_participants'] is int ? data['max_participants'] as int : 20;
      final int? hostId = _extractHostUserId(data);
      final participants =
          _participantsFrom(data['participants'], hostUserId: hostId);
      final playbackState = data['playback_state'] is Map
          ? Map<String, dynamic>.from(data['playback_state'] as Map)
          : const <String, dynamic>{};

      _httpSyncHealthy = true;
      final threads = _mapListFrom(
        playbackState['suggestion_threads'] ?? playbackState['suggestions'],
      );
      final sharedTracks = _tracksFromRaw(playbackState['shared_queue']);

      emit(ConnectActive(
        sessionId: sessionId,
        inviteCode: inviteCode,
        isHost: true,
        participants: participants,
        reactions: _mapListFrom(playbackState['reactions']),
        suggestions: threads,
        suggestionThreads: threads,
        sharedPlaylistTitle:
            (playbackState['shared_playlist_title'] ?? _sharedPlaylistTitle)
                .toString(),
        sharedQueue: sharedTracks.isNotEmpty ? sharedTracks : initialQueue,
        maxParticipants: maxParticipants,
        connectionStatus: 'connected',
      ));

      _startListening(sessionId);
    } catch (_) {
      emit(const ConnectError(
          "Impossible de créer la session Connect. Vérifiez votre connexion."));
    }
  }

  Future<void> joinSession(String inviteCode) async {
    emit(ConnectLoading());
    try {
      final avatar = await _resolveMyAvatarPayload();
      final data = await repository.joinSession(
        inviteCode,
        avatar: avatar,
      );
      final int sessionId = data['id'] as int;
      final int maxParticipants =
          data['max_participants'] is int ? data['max_participants'] as int : 20;
      final int? hostId = _extractHostUserId(data);
      final String hostUsername = (data['host_user'] is Map
              ? (data['host_user']['username'] ?? '')
              : '')
          .toString()
          .trim()
          .toLowerCase();
      final String myUsername = storageService.username.trim().toLowerCase();
      final bool isHost =
          hostUsername.isNotEmpty && hostUsername == myUsername;

      final participants =
          _participantsFrom(data['participants'], hostUserId: hostId);
      final playbackState = data['playback_state'] is Map
          ? Map<String, dynamic>.from(data['playback_state'] as Map)
          : const <String, dynamic>{};

      _httpSyncHealthy = true;
      _lastAppliedRemoteSeq = -1;
      final threads = _mapListFrom(
        playbackState['suggestion_threads'] ?? playbackState['suggestions'],
      );
      final sharedTracks = _tracksFromRaw(playbackState['shared_queue']);
      final sharedTitle =
          (playbackState['shared_playlist_title'] ?? 'File du salon')
              .toString();

      emit(ConnectActive(
        sessionId: sessionId,
        inviteCode: (data['invite_code'] ?? inviteCode).toString(),
        isHost: isHost,
        participants: participants,
        reactions: _mapListFrom(playbackState['reactions']),
        suggestions: threads,
        suggestionThreads: threads,
        sharedPlaylistTitle: sharedTitle,
        sharedQueue: sharedTracks,
        maxParticipants: maxParticipants,
        connectionStatus: 'connected',
      ));

      _startListening(sessionId);

      if (!isHost && playbackState.isNotEmpty) {
        final double? serverNow = data['server_now'] is num
            ? (data['server_now'] as num).toDouble()
            : null;
        await _applyHttpPlaybackState(playbackState, serverNow: serverNow);
      }
    } catch (_) {
      emit(const ConnectError(
          "Code d'invitation invalide ou session terminée."));
    }
  }

  void _startListening(int sessionId) {
    final token = storageService.accessToken ?? '';
    _wsSubscription?.cancel();
    webSocketService.disconnect();

    _wsSubscription = webSocketService.eventStream.listen((data) {
      if (state is! ConnectActive) return;
      final currentState = state as ConnectActive;
      final eventType = data['event'];

      if (eventType == 'session_ended') {
        _terminateLocalSession("La session a été fermée par l'hôte.");
        return;
      }

      if (eventType == 'connected') {
        emit(currentState.copyWith(connectionStatus: 'connected'));
        return;
      }

      if (eventType == 'disconnected' || eventType == 'error') {
        if (!_httpSyncHealthy) {
          emit(currentState.copyWith(connectionStatus: 'disconnected'));
        }
        return;
      }

      if (eventType == 'participant_joined' && currentState.isHost) {
        _hostSeq++;
        unawaited(_performHttpSync(forceHostState: true));
      } else {
        // Chemin unique idempotent via snapshot séquencé
        unawaited(_performHttpSync());
      }
    });

    webSocketService.connect(sessionId: sessionId, accessToken: token);
    _startHttpSyncLoop();

    if (state is ConnectActive && (state as ConnectActive).isHost) {
      _watchHostPlayer();
    }
  }

  void _startHttpSyncLoop() {
    _httpSyncTimer?.cancel();
    _httpSyncTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      unawaited(_performHttpSync());
    });
  }

  Future<void> _performHttpSync({
    String? reaction,
    Map<String, dynamic>? suggestionPayload,
    String? upvoteSuggestionId,
    String? clearSuggestionId,
    bool forceHostState = false,
  }) async {
    if (state is! ConnectActive) return;

    final bool hasExplicitAction = reaction != null ||
        suggestionPayload != null ||
        upvoteSuggestionId != null ||
        clearSuggestionId != null;

    if (_isSyncInFlight) {
      if (forceHostState && !hasExplicitAction) {
        _pendingUrgentHostSync = true;
        return;
      }
      if (!hasExplicitAction && !forceHostState) {
        return;
      }
    }

    final currentState = state as ConnectActive;
    _isSyncInFlight = true;
    try {
      final avatar = await _resolveMyAvatarPayload();
      final pState = playerCubit.state;
      final curTrack = pState.currentTrack;
      final hostWindowQueue =
          currentState.isHost ? _extractHostWindowQueue(pState) : null;

      final data = await repository.syncSession(
        currentState.sessionId,
        avatar: avatar,
        seq: currentState.isHost ? _hostSeq : null,
        track: (currentState.isHost && curTrack != null)
            ? _shareableTrack(curTrack)
            : null,
        position: currentState.isHost
            ? pState.position.inMilliseconds / 1000.0
            : null,
        isPlaying: currentState.isHost ? pState.isPlaying : null,
        isBuffering: currentState.isHost ? pState.isBuffering : null,
        sharedPlaylistTitle:
            currentState.isHost ? _sharedPlaylistTitle : null,
        sharedQueue: hostWindowQueue?.map(_shareableTrack).toList(),
        reaction: reaction,
        suggestionPayload: suggestionPayload,
        upvoteSuggestionId: upvoteSuggestionId,
        clearSuggestionId: clearSuggestionId,
      );

      if (state is! ConnectActive) return;
      final latestState = state as ConnectActive;

      if (data['status'] == 'ended' || data['event'] == 'session_ended') {
        _terminateLocalSession("La session a été fermée par l'hôte.");
        return;
      }

      _httpSyncHealthy = true;
      final int maxParticipants = data['max_participants'] is int
          ? data['max_participants'] as int
          : latestState.maxParticipants;
      final int? hostId = _extractHostUserId(data);
      final participants =
          _participantsFrom(data['participants'], hostUserId: hostId);
      final playbackState = data['playback_state'] is Map
          ? Map<String, dynamic>.from(data['playback_state'] as Map)
          : const <String, dynamic>{};
      final reactions = _mapListFrom(playbackState['reactions']);
      final threads = _mapListFrom(
        playbackState['suggestion_threads'] ?? playbackState['suggestions'],
      );
      final remoteQueue = _tracksFromRaw(playbackState['shared_queue']);
      final remoteTitle =
          (playbackState['shared_playlist_title'] ?? 'File du salon')
              .toString();

      emit(latestState.copyWith(
        participants:
            participants.isNotEmpty ? participants : latestState.participants,
        reactions: reactions,
        suggestions: threads,
        suggestionThreads: threads,
        sharedPlaylistTitle:
            latestState.isHost ? _sharedPlaylistTitle : remoteTitle,
        sharedQueue: latestState.isHost
            ? (hostWindowQueue ?? latestState.sharedQueue)
            : remoteQueue,
        maxParticipants: maxParticipants,
        connectionStatus: 'connected',
      ));

      if (!latestState.isHost && playbackState.isNotEmpty) {
        final double? serverNow = data['server_now'] is num
            ? (data['server_now'] as num).toDouble()
            : null;
        await _applyHttpPlaybackState(playbackState, serverNow: serverNow);
      }
    } catch (_) {
      _httpSyncHealthy = false;
    } finally {
      _isSyncInFlight = false;
      if (_pendingUrgentHostSync && state is ConnectActive) {
        _pendingUrgentHostSync = false;
        unawaited(_performHttpSync(forceHostState: true));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ACTIONS MUSICALES DE L'HÔTE (PLAYLISTS, ALBUMS, SONS & GESTION DES THREADS)
  // ---------------------------------------------------------------------------

  /// Lance une playlist ou un album côté hôte et l'affiche en direct chez tous les participants.
  Future<void> hostPlayTrackList(
    List<TrackModel> tracks, {
    required String title,
    int startIndex = 0,
  }) async {
    if (tracks.isEmpty) return;
    final cleanTitle = title.trim().isEmpty ? 'Playlist du salon' : title.trim();
    final safeIndex = startIndex.clamp(0, tracks.length - 1);
    _sharedPlaylistTitle = cleanTitle;
    _hostSeq++;

    if (state is ConnectActive) {
      final cur = state as ConnectActive;
      emit(cur.copyWith(
        sharedPlaylistTitle: cleanTitle,
        sharedQueue: tracks.take(30).toList(),
      ));
    }

    await playerCubit.playTrack(
      tracks[safeIndex],
      queue: tracks,
      source: cleanTitle,
    );
    await _performHttpSync(forceHostState: true);
  }

  /// Lance directement un son cliqué par l'hôte dans la playlist partagée du salon.
  Future<void> hostJumpToSharedTrack(TrackModel track) async {
    if (state is! ConnectActive) return;
    final cur = state as ConnectActive;
    if (!cur.isHost) return;

    _hostSeq++;
    final queueIdx =
        playerCubit.state.queue.indexWhere((t) => t.id == track.id);
    if (queueIdx >= 0) {
      if (queueIdx == playerCubit.state.currentIndex) {
        await playerCubit.seek(Duration.zero);
        await playerCubit.play();
      } else {
        await playerCubit.skipToQueueItem(queueIdx);
      }
    } else {
      final baseQueue = cur.sharedQueue.isNotEmpty
          ? List<TrackModel>.from(cur.sharedQueue)
          : [track];
      if (!baseQueue.any((t) => t.id == track.id)) {
        baseQueue.add(track);
      }
      await playerCubit.playTrack(
        track,
        queue: baseQueue,
        source: _sharedPlaylistTitle,
      );
    }
    await _performHttpSync(forceHostState: true);
  }

  /// Ajoute un son recherché par l'hôte juste après le morceau en cours dans le salon.
  Future<void> hostAddTrackNext(TrackModel track) async {
    if (state is! ConnectActive) return;
    final cur = state as ConnectActive;
    if (!cur.isHost) return;

    playerCubit.playTrackNext(track);
    _hostSeq++;
    emit(cur.copyWith(sharedQueue: _extractHostWindowQueue(playerCubit.state)));
    await _performHttpSync(forceHostState: true);
  }

  /// Accepte immédiatement un thread de suggestion (son, album ou playlist) et le lance dans le salon.
  Future<void> hostAcceptSuggestionNow(Map<String, dynamic> thread) async {
    if (state is! ConnectActive) return;
    final cur = state as ConnectActive;
    if (!cur.isHost) return;

    final String sid = (thread['id'] ?? '').toString();
    final String kind = (thread['kind'] ?? 'track').toString();
    final String title = (thread['title'] ?? 'Suggestion').toString();
    final List<TrackModel> tracks = _tracksFromRaw(thread['tracks']);
    if (tracks.isEmpty) {
      await hostDismissSuggestion(sid);
      return;
    }

    final remainingThreads = cur.suggestionThreads
        .where((t) => (t['id'] ?? '').toString() != sid)
        .toList();
    emit(cur.copyWith(
      suggestions: remainingThreads,
      suggestionThreads: remainingThreads,
    ));

    _hostSeq++;
    if (kind == 'album' || kind == 'playlist' || tracks.length > 1) {
      _sharedPlaylistTitle = title;
      await playerCubit.playTrack(
        tracks.first,
        queue: tracks,
        source: title,
      );
    } else {
      final single = tracks.first;
      if (playerCubit.state.queue.isEmpty) {
        await playerCubit.playTrack(
          single,
          queue: [single],
          source: _sharedPlaylistTitle,
        );
      } else {
        playerCubit.playTrackNext(single);
        final nextIdx =
            playerCubit.state.queue.indexWhere((t) => t.id == single.id);
        if (nextIdx >= 0) {
          await playerCubit.skipToQueueItem(nextIdx);
        }
      }
    }

    await _performHttpSync(
      clearSuggestionId: sid.isNotEmpty ? sid : null,
      forceHostState: true,
    );
  }

  /// Ajoute les titres d'un thread de suggestion à la suite du morceau en cours dans le salon.
  Future<void> hostQueueSuggestionNext(Map<String, dynamic> thread) async {
    if (state is! ConnectActive) return;
    final cur = state as ConnectActive;
    if (!cur.isHost) return;

    final String sid = (thread['id'] ?? '').toString();
    final List<TrackModel> tracks = _tracksFromRaw(thread['tracks']);
    if (tracks.isEmpty) {
      await hostDismissSuggestion(sid);
      return;
    }

    final remainingThreads = cur.suggestionThreads
        .where((t) => (t['id'] ?? '').toString() != sid)
        .toList();

    for (final track in tracks.reversed) {
      playerCubit.playTrackNext(track);
    }
    _hostSeq++;

    emit(cur.copyWith(
      suggestions: remainingThreads,
      suggestionThreads: remainingThreads,
      sharedQueue: _extractHostWindowQueue(playerCubit.state),
    ));

    await _performHttpSync(
      clearSuggestionId: sid.isNotEmpty ? sid : null,
      forceHostState: true,
    );
  }

  /// Ignore/ferme un thread de suggestion côté hôte.
  Future<void> hostDismissSuggestion(String suggestionId) async {
    if (state is! ConnectActive || suggestionId.trim().isEmpty) return;
    final cur = state as ConnectActive;
    final remaining = cur.suggestionThreads
        .where((t) => (t['id'] ?? '').toString() != suggestionId)
        .toList();
    emit(cur.copyWith(
      suggestions: remaining,
      suggestionThreads: remaining,
    ));
    await _performHttpSync(clearSuggestionId: suggestionId);
  }

  // ---------------------------------------------------------------------------
  // SUGGESTIONS & RÉACTIONS DES PARTICIPANTS (AVEC THREADS DE PRIORITÉ)
  // ---------------------------------------------------------------------------

  Future<void> sendReaction(String emoji) async {
    if (state is! ConnectActive) return;
    await _performHttpSync(reaction: emoji);
  }

  Future<void> suggestTrack(TrackModel track) async {
    if (state is! ConnectActive) return;
    await _performHttpSync(
      suggestionPayload: <String, dynamic>{
        'kind': 'track',
        'title': track.title,
        'subtitle': track.artistName,
        'cover_url': track.coverUrl,
        'tracks': [_shareableTrack(track)],
      },
    );
  }

  Future<void> suggestAlbum({
    required String title,
    required String artistName,
    required String coverUrl,
    required List<TrackModel> tracks,
  }) async {
    if (state is! ConnectActive || tracks.isEmpty) return;
    await _performHttpSync(
      suggestionPayload: <String, dynamic>{
        'kind': 'album',
        'title': title,
        'subtitle': '$artistName • ${tracks.length} titres',
        'cover_url': coverUrl.isNotEmpty ? coverUrl : tracks.first.coverUrl,
        'tracks': tracks.take(30).map(_shareableTrack).toList(),
      },
    );
  }

  Future<void> suggestPlaylist(PlaylistModel playlist) async {
    if (state is! ConnectActive || playlist.tracks.isEmpty) return;
    await _performHttpSync(
      suggestionPayload: <String, dynamic>{
        'kind': 'playlist',
        'title': playlist.name,
        'subtitle': '${playlist.tracks.length} titres',
        'cover_url': playlist.coverUrl.startsWith('http')
            ? playlist.coverUrl
            : playlist.tracks.first.coverUrl,
        'tracks': playlist.tracks.take(30).map(_shareableTrack).toList(),
      },
    );
  }

  Future<void> suggestCurrentTrackToHost() async {
    if (state is! ConnectActive) return;
    final currentTrack = playerCubit.state.currentTrack;
    if (currentTrack == null) return;
    await suggestTrack(currentTrack);
  }

  Future<void> upvoteSuggestion(String suggestionId) async {
    if (state is! ConnectActive || suggestionId.trim().isEmpty) return;
    await _performHttpSync(upvoteSuggestionId: suggestionId.trim());
  }

  // ---------------------------------------------------------------------------
  // APPLICATION IDEMPOTENTE CÔTÉ INVITÉ (ZÉRO REJEU D'ACTIONS PRÉCÉDENTES)
  // ---------------------------------------------------------------------------

  Future<void> _applyHttpPlaybackState(
    Map<String, dynamic> playbackState, {
    double? serverNow,
  }) async {
    final int incomingSeq = playbackState['seq'] is num
        ? (playbackState['seq'] as num).toInt()
        : 0;
    if (incomingSeq > 0 && incomingSeq < _lastAppliedRemoteSeq) {
      // Paquet réseau plus ancien que le dernier état déjà appliqué : ignoré !
      return;
    }
    if (incomingSeq > 0) {
      _lastAppliedRemoteSeq = incomingSeq;
    }

    final rawTrack = playbackState['track'];
    if (rawTrack is! Map) return;

    final trackMap = Map<String, dynamic>.from(rawTrack);
    final String? ytVid = trackMap['youtube_video_id']?.toString().trim();

    TrackModel? track;
    try {
      track = TrackModel.fromJson(trackMap);
    } catch (_) {}
    if (track == null) return;

    final bool hostIsPlaying = playbackState['is_playing'] == true;
    final bool hostIsBuffering = playbackState['is_buffering'] == true;
    double hostPos = playbackState['position'] is num
        ? (playbackState['position'] as num).toDouble()
        : 0.0;
    final double? serverTs = playbackState['server_timestamp'] is num
        ? (playbackState['server_timestamp'] as num).toDouble()
        : null;

    // Ne compenser le temps écoulé que lorsque le flux de l'hôte joue réellement (hors buffering)
    if (hostIsPlaying &&
        !hostIsBuffering &&
        serverNow != null &&
        serverTs != null) {
      final double elapsed = (serverNow - serverTs).clamp(0.0, 6.0);
      hostPos += elapsed;
    }

    final List<TrackModel> remoteQueue =
        _tracksFromRaw(playbackState['shared_queue']);
    final String sharedTitle =
        (playbackState['shared_playlist_title'] ?? 'Sonoritiz Connect')
            .toString();

    final Duration targetDuration =
        Duration(milliseconds: (hostPos * 1000).round().clamp(0, 86400000));

    // Tant que l'hôte est en train de charger le flux (is_buffering), l'invité pré-charge
    // immédiatement au même point sans démarrer le son en avance.
    final bool effectiveShouldPlay = hostIsPlaying && !hostIsBuffering;

    await playerCubit.syncConnectTargetState(
      track: track,
      queue: remoteQueue.isNotEmpty ? remoteQueue : [track],
      targetPosition: targetDuration,
      shouldPlay: effectiveShouldPlay,
      source: sharedTitle,
      preResolvedYoutubeId:
          (ytVid != null && ytVid.isNotEmpty) ? ytVid : null,
    );
  }

  void _terminateLocalSession(String message) {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _httpSyncTimer?.cancel();
    _httpSyncTimer = null;
    _hostPublishDebounce?.cancel();
    _hostPublishDebounce = null;
    webSocketService.disconnect();
    _stopWatchingPlayer();
    emit(ConnectError(message));
  }

  void reconnect() {
    if (state is ConnectActive) {
      final activeState = state as ConnectActive;
      emit(activeState.copyWith(connectionStatus: 'connecting'));
      _startListening(activeState.sessionId);
      unawaited(_performHttpSync(forceHostState: activeState.isHost));
    }
  }

  void _watchHostPlayer() {
    _playerSubscription?.cancel();
    _syncTimer?.cancel();
    _lastPlayerState = playerCubit.state;
    _publishPlayerStateImmediate(playerCubit.state);
    _playerSubscription = playerCubit.stream.listen(_onHostPlayerChanged);
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final current = state;
      if (current is ConnectActive && current.isHost) {
        unawaited(_performHttpSync(forceHostState: true));
      }
    });
  }

  void _stopWatchingPlayer() {
    _playerSubscription?.cancel();
    _playerSubscription = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    _httpSyncTimer?.cancel();
    _httpSyncTimer = null;
    _hostPublishDebounce?.cancel();
    _hostPublishDebounce = null;
    _lastPlayerState = null;
  }

  void _publishPlayerStateImmediate(PlayerState playerState) {
    _hostPublishDebounce?.cancel();
    _hostSeq++;
    final track = playerState.currentTrack;
    webSocketService.sendSyncState(
      positionSeconds: playerState.position.inMilliseconds / 1000,
      isPlaying: playerState.isPlaying,
      trackId: track?.id,
      track: track == null ? null : _shareableTrack(track),
    );
    unawaited(_performHttpSync(forceHostState: true));
  }

  /// Coalesce les clics rapides Play -> Pause -> Play en un seul état final séquencé (160 ms).
  void _scheduleDebouncedHostPublish() {
    _hostPublishDebounce?.cancel();
    _hostPublishDebounce = Timer(const Duration(milliseconds: 160), () {
      if (isClosed || state is! ConnectActive) return;
      final cur = state as ConnectActive;
      if (!cur.isHost) return;
      _publishPlayerStateImmediate(playerCubit.state);
    });
  }

  void _onHostPlayerChanged(PlayerState next) {
    if (state is! ConnectActive || !(state as ConnectActive).isHost) return;
    final previous = _lastPlayerState;
    _lastPlayerState = next;
    if (previous == null) {
      _publishPlayerStateImmediate(next);
      return;
    }

    final nextTrack = next.currentTrack;
    final previousTrackId = previous.currentTrack?.id;

    // 1. Changement de morceau : publier immédiatement pour lancer le pré-chargement chez les invités
    if (nextTrack?.id != previousTrackId) {
      if (nextTrack != null) {
        _publishPlayerStateImmediate(next);
      }
      return;
    }

    // 2. Fin du buffering sur l'hôte : l'ID vidéo YouTube est maintenant résolu et le son démarre réellement !
    if (previous.isBuffering != next.isBuffering && !next.isBuffering) {
      _publishPlayerStateImmediate(next);
      return;
    }

    // 3. Mise à jour de la file d'attente de l'hôte
    if (next.queue.length != previous.queue.length) {
      _scheduleDebouncedHostPublish();
      return;
    }

    // 4. Play / Pause (avec anti-rebond 160ms pour éviter tout rejeu d'actions successives)
    if (next.isPlaying != previous.isPlaying) {
      _scheduleDebouncedHostPublish();
      return;
    }

    // 5. Saut de position (Seek manuel > 2.5s)
    if (nextTrack != null &&
        (next.position - previous.position).inMilliseconds.abs() > 2500) {
      _scheduleDebouncedHostPublish();
    }
  }

  Future<void> leaveSession() async {
    if (state is ConnectActive) {
      final currentState = state as ConnectActive;
      try {
        await repository.leaveSession(currentState.sessionId);
      } catch (_) {}
    }

    _wsSubscription?.cancel();
    _stopWatchingPlayer();
    webSocketService.disconnect();
    emit(ConnectInitial());
  }

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
    _stopWatchingPlayer();
    webSocketService.dispose();
    return super.close();
  }
}
