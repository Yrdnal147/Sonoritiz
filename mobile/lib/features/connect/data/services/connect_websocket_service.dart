import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../core/constants/api_constants.dart';

class ConnectWebSocketService {
  WebSocketChannel? _channel;
  bool _channelReady = false;
  final List<String> _pendingMessages = [];
  final StreamController<Map<String, dynamic>> _eventController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  void connect({required int sessionId, required String accessToken}) {
    final wsUrl = '${ApiConstants.wsBaseUrl}/ws/connect/$sessionId/?token=$accessToken';
    try {
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel = channel;
      _waitUntilReady(channel);

      channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (identical(_channel, channel) &&
                !_eventController.isClosed &&
                data is Map<String, dynamic>) {
              _eventController.add(data);
            }
          } catch (_) {}
        },
        onError: (err) {
          if (identical(_channel, channel) && !_eventController.isClosed) {
            _channelReady = false;
            _channel = null;
            _pendingMessages.clear();
            _eventController.add({'event': 'error', 'message': 'Connexion WebSocket interrompue'});
          }
        },
        onDone: () {
          if (identical(_channel, channel) && !_eventController.isClosed) {
            _channelReady = false;
            _channel = null;
            _pendingMessages.clear();
            _eventController.add({'event': 'disconnected'});
          }
        },
      );
    } catch (e) {
      if (!_eventController.isClosed) {
        _eventController.add({'event': 'error', 'message': 'Impossible de se connecter à la session'});
      }
    }
  }

  Future<void> _waitUntilReady(WebSocketChannel channel) async {
    try {
      await channel.ready;
      if (identical(_channel, channel) && !_eventController.isClosed) {
        _channelReady = true;
        _eventController.add({'event': 'connected'});
        for (final message in List<String>.from(_pendingMessages)) {
          channel.sink.add(message);
        }
        _pendingMessages.clear();
      }
    } catch (_) {
      if (identical(_channel, channel) && !_eventController.isClosed) {
        _channelReady = false;
        _pendingMessages.clear();
        _eventController.add({'event': 'error', 'message': 'Connexion refusée'});
      }
    }
  }

  void sendPlay(double positionSeconds) {
    _send({'event': 'play', 'position': positionSeconds});
  }

  void sendPause(double positionSeconds) {
    _send({'event': 'pause', 'position': positionSeconds});
  }

  void sendSeek(double positionSeconds) {
    _send({'event': 'seek', 'position': positionSeconds});
  }

  void sendTrackChanged(
    String trackId, {
    Map<String, dynamic>? track,
    required double positionSeconds,
    required bool isPlaying,
  }) {
    _send({
      'event': 'track_changed',
      'track_id': trackId,
      'position': positionSeconds,
      'is_playing': isPlaying,
      if (track != null) 'track': track,
    });
  }

  void sendSyncState({
    required double positionSeconds,
    required bool isPlaying,
    String? trackId,
    Map<String, dynamic>? track,
  }) {
    _send({
      'event': 'sync_state',
      'position': positionSeconds,
      'is_playing': isPlaying,
      if (trackId != null) 'track_id': trackId,
      if (track != null) 'track': track,
    });
  }

  void _send(Map<String, dynamic> data) {
    final channel = _channel;
    if (channel != null) {
      final message = jsonEncode(data);
      if (!_channelReady) {
        _pendingMessages.add(message);
        return;
      }
      try {
        channel.sink.add(message);
      } catch (_) {
        if (!_eventController.isClosed) {
          _eventController.add({'event': 'error', 'message': 'Envoi du contrôle impossible'});
        }
      }
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _channelReady = false;
    _pendingMessages.clear();
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}
