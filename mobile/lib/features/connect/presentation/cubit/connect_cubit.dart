import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../data/services/connect_websocket_service.dart';
import 'connect_state.dart';

class ConnectCubit extends Cubit<ConnectState> {
  final ApiClient apiClient;
  final StorageService storageService;
  final ConnectWebSocketService webSocketService = ConnectWebSocketService();
  StreamSubscription? _wsSubscription;

  ConnectCubit({
    required this.apiClient,
    required this.storageService,
  }) : super(ConnectInitial());

  Future<void> createSession() async {
    emit(ConnectLoading());
    try {
      final response = await apiClient.post(ApiConstants.connectSessions);
      if (response.statusCode == 201) {
        final data = response.data;
        final sessionId = data['id'] as int;
        final inviteCode = data['invite_code'] as String;

        emit(ConnectActive(
          sessionId: sessionId,
          inviteCode: inviteCode,
          isHost: true,
          participants: [
            {'username': storageService.username, 'status': 'connected'}
          ],
        ));

        _connectWebSocket(sessionId);
      }
    } catch (e) {
      emit(const ConnectError("Impossible de créer la session Connect."));
    }
  }

  Future<void> joinSession(String inviteCode) async {
    emit(ConnectLoading());
    try {
      final response = await apiClient.post(
        ApiConstants.connectJoin,
        data: {'invite_code': inviteCode},
      );
      if (response.statusCode == 200) {
        final data = response.data;
        final sessionId = data['id'] as int;

        emit(ConnectActive(
          sessionId: sessionId,
          inviteCode: inviteCode,
          isHost: false,
          participants: [
            {'username': storageService.username, 'status': 'connected'}
          ],
        ));

        _connectWebSocket(sessionId);
      }
    } catch (e) {
      emit(const ConnectError("Code d'invitation invalide ou session terminée."));
    }
  }

  void _connectWebSocket(int sessionId) {
    final token = storageService.accessToken ?? '';
    webSocketService.connect(sessionId: sessionId, accessToken: token);

    _wsSubscription?.cancel();
    _wsSubscription = webSocketService.eventStream.listen((event) {
      if (state is ConnectActive) {
        final currentState = state as ConnectActive;
        final eventType = event['event'];

        if (eventType == 'participant_joined') {
          final user = event['user'] ?? {};
          final username = user['username'] ?? 'Participant';
          final updated = List<Map<String, dynamic>>.from(currentState.participants)
            ..add({'username': username, 'status': 'connected'});
          emit(currentState.copyWith(participants: updated));
        } else if (eventType == 'participant_left') {
          final user = event['user'] ?? {};
          final username = user['username'] ?? '';
          final updated = List<Map<String, dynamic>>.from(currentState.participants)
            ..removeWhere((p) => p['username'] == username);
          emit(currentState.copyWith(participants: updated));
        }
      }
    });
  }

  Future<void> leaveSession() async {
    if (state is ConnectActive) {
      final currentState = state as ConnectActive;
      try {
        await apiClient.post('${ApiConstants.connectSessions}${currentState.sessionId}/leave/');
      } catch (_) {}
    }
    webSocketService.disconnect();
    emit(ConnectInitial());
  }

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
    webSocketService.dispose();
    return super.close();
  }
}
