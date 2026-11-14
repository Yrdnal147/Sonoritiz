import 'dart:async';
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
  PlayerState? _lastPlayerState;

  ConnectCubit({
    required this.storageService,
    required this.repository,
    required this.playerCubit,
  }) : super(ConnectInitial());

  List<Map<String, dynamic>> _participantsFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((participant) {
      final user = participant['user'];
      if (user is Map) {
        return <String, dynamic>{
          'id': user['id'],
          'username': user['username'] ?? 'Inconnu',
          'status': 'connected',
        };
      }
      return <String, dynamic>{
        'id': participant['id'],
        'username': participant['username'] ?? 'Inconnu',
        'status': 'connected',
      };
    }).toList();
  }

  Future<void> createSession() async {
    emit(ConnectLoading());
    try {
      final data = await repository.createSession();
      final sessionId = data['id'];
      final inviteCode = data['invite_code'];
      final participants = _participantsFrom(data['participants']);

      emit(ConnectActive(
        sessionId: sessionId,
        inviteCode: inviteCode,
        isHost: true,
        participants: participants,
      ));

      _startListening(sessionId);
    } catch (e) {
      print('Error creating session: $e');
      emit(const ConnectError("Impossible de créer la session Connect. Vérifiez votre connexion."));
    }
  }

  Future<void> joinSession(String inviteCode) async {
    emit(ConnectLoading());
    try {
      final data = await repository.joinSession(inviteCode);
      final sessionId = data['id'];
      
      final participants = _participantsFrom(data['participants']);

      emit(ConnectActive(
        sessionId: sessionId,
        inviteCode: data['invite_code'],
        isHost: false,
        participants: participants,
      ));

      _startListening(sessionId);
    } catch (e) {
      print('Error joining session: $e');
      emit(const ConnectError("Code d'invitation invalide ou session terminée."));
    }
  }

  void _startListening(int sessionId) {
    final token = storageService.accessToken ?? '';
    _wsSubscription?.cancel();
    webSocketService.disconnect();
    _wsSubscription = webSocketService.eventStream.listen((data) {
      if (state is ConnectActive) {
        final currentState = state as ConnectActive;
        final eventType = data['event'];

        if (eventType == 'session_ended') {
          emit(const ConnectError("La session a été fermée par l'hôte."));
          _wsSubscription?.cancel();
          _wsSubscription = null;
          webSocketService.disconnect();
          _stopWatchingPlayer();
          return;
        }

        if (eventType == 'connected' || eventType == 'disconnected' || eventType == 'error') {
          emit(currentState.copyWith(
            connectionStatus: eventType == 'connected' ? 'connected' : 'disconnected',
          ));
          return;
        }

        if (eventType == 'participant_joined' || eventType == 'participant_left') {
          if (data.containsKey('participants')) {
            emit(currentState.copyWith(
              participants: _participantsFrom(data['participants']),
            ));
          } else if (data['user'] is Map) {
            final user = Map<String, dynamic>.from(data['user'] as Map);
            final participant = <String, dynamic>{
              'id': user['id'],
              'username': user['username'] ?? 'Inconnu',
              'status': 'connected',
            };
            final participants = List<Map<String, dynamic>>.from(
              currentState.participants,
            );
            final userId = user['id'];
            if (eventType == 'participant_joined') {
              participants.removeWhere((item) =>
                  userId != null && item['id'] == userId);
              participants.add(participant);
            } else {
              participants.removeWhere((item) => userId != null
                  ? item['id'] == userId
                  : item['username'] == participant['username']);
            }
            emit(currentState.copyWith(participants: participants));
          }
        }

        if (eventType == 'participant_joined' && currentState.isHost) {
          _publishPlayerState(playerCubit.state);
        } else if (!currentState.isHost) {
          unawaited(_applyRemotePlaybackEvent(data));
        }
      }
    });

    webSocketService.connect(sessionId: sessionId, accessToken: token);
    if (state is ConnectActive && (state as ConnectActive).isHost) {
      _watchHostPlayer();
    }
  }

  void reconnect() {
    if (state is ConnectActive) {
      final activeState = state as ConnectActive;
      emit(activeState.copyWith(connectionStatus: 'connecting'));
      _startListening(activeState.sessionId);
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
      if (current is ConnectActive &&
          current.isHost &&
          current.connectionStatus == 'connected') {
        _publishPlayerState(playerCubit.state);
      }
    });
  }

  void _stopWatchingPlayer() {
    _playerSubscription?.cancel();
    _playerSubscription = null;
    _syncTimer?.cancel();
    _syncTimer = null;
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
      }
      return;
    }

    if (next.isPlaying != previous.isPlaying) {
      if (next.isPlaying) {
        webSocketService.sendPlay(next.position.inMilliseconds / 1000);
      } else {
        webSocketService.sendPause(next.position.inMilliseconds / 1000);
      }
      return;
    }

    if (nextTrack != null &&
        (next.position - previous.position).inMilliseconds.abs() > 3000) {
      webSocketService.sendSeek(next.position.inMilliseconds / 1000);
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
    final positionSeconds = positionValue is num ? positionValue.toDouble() : 0.0;
    if ((type == 'play' || type == 'pause' || type == 'seek' ||
            type == 'sync_state' ||
            (type == 'track_changed' && event.containsKey('position'))) &&
        playerCubit.state.hasTrack && positionSeconds >= 0) {
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
      } catch (_) {
        return;
      }
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
