import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/storage_service.dart';
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
  PlayerState? _lastPlayerState;
  bool _httpSyncHealthy = false;
  bool _isSyncInFlight = false;
  String? _cachedMyAvatarPayload;
  String? _lastAvatarSourcePath;
  final Set<String> _consumedSuggestionIds = <String>{};

  ConnectCubit({
    required this.storageService,
    required this.repository,
    required this.playerCubit,
  }) : super(ConnectInitial());

  /// Résout la photo de profil de l'utilisateur courant :
  /// 1. Si l'utilisateur a choisi une photo dans sa galerie (`getProfileImagePath()`),
  ///    la redimensionne en miniature 72x72 (`data:image/png;base64,...`, ~8 Ko)
  ///    afin que tous les autres participants voient sa vraie photo sur leur téléphone.
  /// 2. Sinon, si c'est une URL http/https, l'utilise directement.
  /// 3. Sinon, utilise la photo de son 1er artiste consulté/suivi comme avatar musical.
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

  int? _extractHostUserId(Map<String, dynamic> data) {
    final hostUser = data['host_user'];
    if (hostUser is Map && hostUser['id'] != null) {
      return hostUser['id'] is int
          ? hostUser['id'] as int
          : int.tryParse(hostUser['id'].toString());
    }
    return null;
  }

  Future<void> createSession() async {
    emit(ConnectLoading());
    try {
      final avatar = await _resolveMyAvatarPayload();
      final currentTrack = playerCubit.state.currentTrack;
      final data = await repository.createSession(
        avatar: avatar,
        initialTrack:
            currentTrack != null ? _shareableTrack(currentTrack) : null,
        position: playerCubit.state.position.inMilliseconds / 1000.0,
        isPlaying: playerCubit.state.isPlaying,
      );
      final int sessionId = data['id'] as int;
      final String inviteCode = (data['invite_code'] ?? '').toString();
      final int? hostId = _extractHostUserId(data);
      final participants =
          _participantsFrom(data['participants'], hostUserId: hostId);
      final playbackState = data['playback_state'] is Map
          ? Map<String, dynamic>.from(data['playback_state'] as Map)
          : const <String, dynamic>{};

      _httpSyncHealthy = true;
      _consumedSuggestionIds.clear();

      emit(ConnectActive(
        sessionId: sessionId,
        inviteCode: inviteCode,
        isHost: true,
        participants: participants,
        reactions: _mapListFrom(playbackState['reactions']),
        suggestions: _mapListFrom(playbackState['suggestions']),
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
      _consumedSuggestionIds.clear();

      emit(ConnectActive(
        sessionId: sessionId,
        inviteCode: (data['invite_code'] ?? inviteCode).toString(),
        isHost: isHost,
        participants: participants,
        reactions: _mapListFrom(playbackState['reactions']),
        suggestions: _mapListFrom(playbackState['suggestions']),
        connectionStatus: 'connected',
      ));

      _startListening(sessionId);

      if (!isHost && playbackState.isNotEmpty) {
        final double? serverNow =
            data['server_now'] is num ? (data['server_now'] as num).toDouble() : null;
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

      // Sur Vercel Serverless, le WebSocket se ferme immédiatement :
      // si la synchro HTTP fonctionne (_httpSyncHealthy), on reste en 'connected' !
      if (eventType == 'disconnected' || eventType == 'error') {
        if (!_httpSyncHealthy) {
          emit(currentState.copyWith(connectionStatus: 'disconnected'));
        }
        return;
      }

      if (eventType == 'participant_joined' ||
          eventType == 'participant_left') {
        unawaited(_performHttpSync());
      }

      if (eventType == 'participant_joined' && currentState.isHost) {
        _publishPlayerState(playerCubit.state);
      } else if (!currentState.isHost) {
        unawaited(_applyRemotePlaybackEvent(data));
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
    _httpSyncTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      unawaited(_performHttpSync());
    });
  }

  Future<void> _performHttpSync({
    String? reaction,
    Map<String, dynamic>? suggestedTrack,
    String? clearSuggestionId,
    bool forceHostState = false,
  }) async {
    if (state is! ConnectActive) return;
    if (_isSyncInFlight &&
        reaction == null &&
        suggestedTrack == null &&
        clearSuggestionId == null &&
        !forceHostState) {
      return;
    }

    final currentState = state as ConnectActive;
    _isSyncInFlight = true;
    try {
      final avatar = await _resolveMyAvatarPayload();
      final pState = playerCubit.state;
      final curTrack = pState.currentTrack;

      final data = await repository.syncSession(
        currentState.sessionId,
        avatar: avatar,
        track: (currentState.isHost && curTrack != null)
            ? _shareableTrack(curTrack)
            : null,
        position: currentState.isHost
            ? pState.position.inMilliseconds / 1000.0
            : null,
        isPlaying: currentState.isHost ? pState.isPlaying : null,
        reaction: reaction,
        suggestedTrack: suggestedTrack,
        clearSuggestionId: clearSuggestionId,
      );

      if (state is! ConnectActive) return;
      final latestState = state as ConnectActive;

      if (data['status'] == 'ended' || data['event'] == 'session_ended') {
        _terminateLocalSession("La session a été fermée par l'hôte.");
        return;
      }

      _httpSyncHealthy = true;
      final int? hostId = _extractHostUserId(data);
      final participants =
          _participantsFrom(data['participants'], hostUserId: hostId);
      final playbackState = data['playback_state'] is Map
          ? Map<String, dynamic>.from(data['playback_state'] as Map)
          : const <String, dynamic>{};
      final reactions = _mapListFrom(playbackState['reactions']);
      final suggestions = _mapListFrom(playbackState['suggestions']);

      emit(latestState.copyWith(
        participants:
            participants.isNotEmpty ? participants : latestState.participants,
        reactions: reactions,
        suggestions: suggestions,
        connectionStatus: 'connected',
      ));

      if (latestState.isHost) {
        // Ajouter automatiquement les nouveaux sons suggérés par les participants à la file d'attente de l'hôte
        for (final s in suggestions) {
          final sid = (s['id'] ?? '').toString();
          if (sid.isNotEmpty && _consumedSuggestionIds.add(sid)) {
            try {
              final track = TrackModel.fromJson(s);
              playerCubit.addToQueue(track);
              unawaited(repository.syncSession(
                latestState.sessionId,
                clearSuggestionId: sid,
              ));
            } catch (_) {}
          }
        }
      } else if (playbackState.isNotEmpty) {
        final double? serverNow = data['server_now'] is num
            ? (data['server_now'] as num).toDouble()
            : null;
        await _applyHttpPlaybackState(playbackState, serverNow: serverNow);
      }
    } catch (_) {
      _httpSyncHealthy = false;
    } finally {
      _isSyncInFlight = false;
    }
  }

  Future<void> sendReaction(String emoji) async {
    if (state is! ConnectActive) return;
    await _performHttpSync(reaction: emoji);
  }

  Future<void> suggestCurrentTrackToHost() async {
    if (state is! ConnectActive) return;
    final currentTrack = playerCubit.state.currentTrack;
    if (currentTrack == null) return;
    await _performHttpSync(suggestedTrack: _shareableTrack(currentTrack));
  }

  Future<void> _applyHttpPlaybackState(
    Map<String, dynamic> playbackState, {
    double? serverNow,
  }) async {
    final rawTrack = playbackState['track'];
    if (rawTrack is! Map) return;

    TrackModel? track;
    try {
      track = TrackModel.fromJson(Map<String, dynamic>.from(rawTrack));
    } catch (_) {}
    if (track == null) return;

    final bool hostIsPlaying = playbackState['is_playing'] == true;
    double hostPos = playbackState['position'] is num
        ? (playbackState['position'] as num).toDouble()
        : 0.0;
    final double? serverTs = playbackState['server_timestamp'] is num
        ? (playbackState['server_timestamp'] as num).toDouble()
        : null;

    if (hostIsPlaying && serverNow != null && serverTs != null) {
      final double elapsed = (serverNow - serverTs).clamp(0.0, 12.0);
      hostPos += elapsed;
    }

    final bool isDifferentTrack =
        playerCubit.state.currentTrack?.id != track.id;
    if (isDifferentTrack) {
      final queue = List<TrackModel>.from(playerCubit.state.queue);
      final existingIndex = queue.indexWhere((item) => item.id == track!.id);
      if (existingIndex < 0) {
        queue.add(track);
      } else {
        queue[existingIndex] = track;
      }
      await playerCubit.playTrack(track, queue: queue, source: 'Connect');
    }

    if (playerCubit.state.hasTrack && hostPos >= 0) {
      final target = Duration(milliseconds: (hostPos * 1000).round());
      final diffMs = (playerCubit.state.position - target).inMilliseconds.abs();
      if (diffMs > 3200) {
        await playerCubit.seek(target);
      }
    }

    if (hostIsPlaying && !playerCubit.state.isPlaying) {
      await playerCubit.play();
    } else if (!hostIsPlaying && playerCubit.state.isPlaying) {
      await playerCubit.pause();
    }
  }

  void _terminateLocalSession(String message) {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _httpSyncTimer?.cancel();
    _httpSyncTimer = null;
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
    _publishPlayerState(playerCubit.state);
    _playerSubscription = playerCubit.stream.listen(_onHostPlayerChanged);
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final current = state;
      if (current is ConnectActive && current.isHost) {
        _publishPlayerState(playerCubit.state);
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
    _lastPlayerState = null;
  }

  Map<String, dynamic> _shareableTrack(TrackModel track) => {
        'id': track.id,
        'title': track.title,
        'artist_name': track.artistName,
        'album_name': track.albumName,
        'cover_url': track.coverUrl,
        'duration_seconds': track.durationSeconds,
        'genre': track.genre,
        'license_ccurl': track.licenseCcUrl,
      };

  void _publishPlayerState(PlayerState playerState) {
    final track = playerState.currentTrack;
    webSocketService.sendSyncState(
      positionSeconds: playerState.position.inMilliseconds / 1000,
      isPlaying: playerState.isPlaying,
      trackId: track?.id,
      track: track == null ? null : _shareableTrack(track),
    );
    unawaited(_performHttpSync(forceHostState: true));
  }

  void _onHostPlayerChanged(PlayerState next) {
    if (state is! ConnectActive || !(state as ConnectActive).isHost) return;
    final previous = _lastPlayerState;
    _lastPlayerState = next;
    if (previous == null) {
      _publishPlayerState(next);
      return;
    }

    final nextTrack = next.currentTrack;
    final previousTrackId = previous.currentTrack?.id;
    if (nextTrack?.id != previousTrackId) {
      if (nextTrack != null) {
        webSocketService.sendTrackChanged(
          nextTrack.id,
          track: _shareableTrack(nextTrack),
          positionSeconds: next.position.inMilliseconds / 1000,
          isPlaying: next.isPlaying,
        );
        unawaited(_performHttpSync(forceHostState: true));
      }
      return;
    }

    if (next.isPlaying != previous.isPlaying) {
      if (next.isPlaying) {
        webSocketService.sendPlay(next.position.inMilliseconds / 1000);
      } else {
        webSocketService.sendPause(next.position.inMilliseconds / 1000);
      }
      unawaited(_performHttpSync(forceHostState: true));
      return;
    }

    if (nextTrack != null &&
        (next.position - previous.position).inMilliseconds.abs() > 3000) {
      webSocketService.sendSeek(next.position.inMilliseconds / 1000);
      unawaited(_performHttpSync(forceHostState: true));
    }
  }

  Future<void> _applyRemotePlaybackEvent(Map<String, dynamic> event) async {
    final type = event['event'];
    final playerState = playerCubit.state;
    final trackId = event['track_id']?.toString();
    TrackModel? track;
    final rawTrack = event['track'];
    if (rawTrack is Map) {
      try {
        track = TrackModel.fromJson(Map<String, dynamic>.from(rawTrack));
      } catch (_) {}
    }

    if (track == null && trackId != null) {
      for (final queuedTrack in playerState.queue) {
        if (queuedTrack.id == trackId) {
          track = queuedTrack;
          break;
        }
      }
    }

    if ((type == 'track_changed' || type == 'sync_state') && track != null) {
      if (playerCubit.state.currentTrack?.id != track.id) {
        final queue = List<TrackModel>.from(playerCubit.state.queue);
        final existingIndex = queue.indexWhere((item) => item.id == track!.id);
        if (existingIndex < 0) {
          queue.add(track);
        } else {
          queue[existingIndex] = track;
        }
        await playerCubit.playTrack(track, queue: queue, source: 'Connect');
      }
    }

    final positionValue = event['position'];
    final positionSeconds =
        positionValue is num ? positionValue.toDouble() : 0.0;
    if ((type == 'play' ||
            type == 'pause' ||
            type == 'seek' ||
            type == 'sync_state' ||
            (type == 'track_changed' && event.containsKey('position'))) &&
        playerCubit.state.hasTrack &&
        positionSeconds >= 0) {
      final target = Duration(milliseconds: (positionSeconds * 1000).round());
      if ((playerCubit.state.position - target).inMilliseconds.abs() > 2000) {
        await playerCubit.seek(target);
      }
    }

    if (type == 'play' ||
        ((type == 'sync_state' || type == 'track_changed') &&
            event['is_playing'] == true)) {
      await playerCubit.play();
    } else if (type == 'pause' ||
        ((type == 'sync_state' || type == 'track_changed') &&
            event['is_playing'] == false)) {
      await playerCubit.pause();
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
