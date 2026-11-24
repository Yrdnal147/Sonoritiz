import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';

class ConnectRepository {
  final ApiClient apiClient;

  ConnectRepository({required this.apiClient});

  Future<Map<String, dynamic>> createSession({
    String? avatar,
    Map<String, dynamic>? initialTrack,
    double? position,
    bool? isPlaying,
  }) async {
    final response = await apiClient.post(
      ApiConstants.connectSessions,
      data: <String, dynamic>{
        if (avatar != null && avatar.isNotEmpty) 'avatar': avatar,
        if (initialTrack != null) 'track': initialTrack,
        if (position != null) 'position': position,
        if (isPlaying != null) 'is_playing': isPlaying,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> joinSession(
    String inviteCode, {
    String? avatar,
  }) async {
    final response = await apiClient.post(
      ApiConstants.connectJoin,
      data: <String, dynamic>{
        'invite_code': inviteCode,
        if (avatar != null && avatar.isNotEmpty) 'avatar': avatar,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> syncSession(
    int sessionId, {
    String? avatar,
    Map<String, dynamic>? track,
    double? position,
    bool? isPlaying,
    String? reaction,
    Map<String, dynamic>? suggestedTrack,
    String? clearSuggestionId,
  }) async {
    final response = await apiClient.post(
      '${ApiConstants.connectSessions}$sessionId/sync/',
      data: <String, dynamic>{
        if (avatar != null && avatar.isNotEmpty) 'avatar': avatar,
        if (track != null) 'track': track,
        if (position != null) 'position': position,
        if (isPlaying != null) 'is_playing': isPlaying,
        if (reaction != null && reaction.isNotEmpty) 'reaction': reaction,
        if (suggestedTrack != null) 'suggested_track': suggestedTrack,
        if (clearSuggestionId != null && clearSuggestionId.isNotEmpty)
          'clear_suggestion_id': clearSuggestionId,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> leaveSession(int sessionId) async {
    await apiClient.post('${ApiConstants.connectSessions}$sessionId/leave/');
  }
}

