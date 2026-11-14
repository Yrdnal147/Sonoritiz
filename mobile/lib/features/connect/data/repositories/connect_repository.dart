import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';

class ConnectRepository {
  final ApiClient apiClient;

  ConnectRepository({required this.apiClient});

  Future<Map<String, dynamic>> createSession() async {
    final response = await apiClient.post(ApiConstants.connectSessions);
    return response.data;
  }

  Future<Map<String, dynamic>> joinSession(String inviteCode) async {
    final response = await apiClient.post(
      ApiConstants.connectJoin,
      data: {'invite_code': inviteCode},
    );
    return response.data;
  }

  Future<void> leaveSession(int sessionId) async {
    await apiClient.post('${ApiConstants.connectSessions}$sessionId/leave/');
  }
}

