import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../core/constants/api_constants.dart';

class ConnectWebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _eventController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  void connect({required int sessionId, required String accessToken}) {
    final wsUrl = '${ApiConstants.wsBaseUrl}/ws/connect/$sessionId/?token=$accessToken';
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data is Map<String, dynamic>) {
              _eventController.add(data);
            }
          } catch (_) {}
        },
        onError: (err) {
          _eventController.add({'event': 'error', 'message': 'WebSocket error'});
        },
        onDone: () {
          _eventController.add({'event': 'disconnected'});
        },
      );
    } catch (e) {
      _eventController.add({'event': 'error', 'message': 'Failed to connect WebSocket'});
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

  void sendTrackChanged(String trackId) {
    _send({'event': 'track_changed', 'track_id': trackId});
  }

  void _send(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}
